import Quickshell
import Quickshell.Io
import Quickshell.I3
import QtQuick
import qs.StatusbarApp

// Owns the status bar's lifecycle and its single "statusbar" IPC target
// (mirrors DockApp/DockLoader.qml). One StatusbarWindow is created per
// connected monitor via Variants over Quickshell.screens (P2.4) -- the IPC
// handler has to live here rather than inside StatusbarWindow itself, since
// an IpcHandler is registered once per target name: N per-monitor instances
// each declaring their own "statusbar" handler would collide.
//
// toggle/enable/disable/alwaysExpand/autoCollapse/autohide* all write
// straight into StatusbarSettings, which every window instance already binds
// to, so no routing is needed for those. focus/expand/collapse are
// inherently per-instance (keyboard grab, expand state) and are routed via
// StatusbarSettings' signals -- see StatusbarWindow's monitorIsFocused guard.
Scope {
    id: root

    IpcHandler {
        target: "statusbar"
        function toggle(): void { StatusbarSettings.setEnabled(!StatusbarSettings.barEnabled) }
        // Named enable/disable rather than show/hide: "show" is a reserved
        // subcommand of "qs ipc" and would never reach the function.
        function enable(): void { StatusbarSettings.setEnabled(true) }
        function disable(): void { StatusbarSettings.setEnabled(false) }
        // Persist and apply the alwaysExpanded (permanently expanded) mode,
        // toggled from the SidebarApp switch.
        function alwaysExpand(): void { StatusbarSettings.setAlwaysExpanded(true) }
        function autoCollapse(): void { StatusbarSettings.setAlwaysExpanded(false) }
        // Persist and apply the autohide mode, toggled from the SidebarApp
        // switch and from the xcloud-toggle-statusbar-autohide script.
        function autohideOn(): void { StatusbarSettings.setAutohide(true) }
        function autohideOff(): void { StatusbarSettings.setAutohide(false) }
        function autohideToggle(): void {
            StatusbarSettings.setAutohide(!StatusbarSettings.autohide)
        }
        // Re-read statusbar.json from disk (used by the SidebarApp switch).
        function refresh(): void { StatusbarSettings.reloadSettings() }
        // Expand the bar on the focused monitor (if needed) and grab the
        // keyboard for navigation. Bound to SUPER + ALT + SPACE.
        function focus(): void { StatusbarSettings.focusRequested() }
        // Toggle between collapsed and expanded mode on the focused monitor.
        function expand(): void { StatusbarSettings.expandToggleRequested() }
        function collapse(): void { StatusbarSettings.collapseRequested() }
        // Re-read statusbar.json and apply the changes.
        function reload(): void { StatusbarSettings.reloadSettings() }
    }

    // --- FULLSCREEN (autohide) ---
    // An autohiding bar is an override-redirect window stacked above every
    // i3 window, so it would stay on top of a fullscreen video. On Hyprland
    // the bar's top layer sits under fullscreen windows; to match, a bar is
    // lowered under the windows while its output's visible workspace has a
    // fullscreen window (see StatusbarWindow.restack; a docked bar needs
    // nothing: i3 already covers docks). Quickshell's I3
    // singleton only follows workspace/output events, so this listens for the
    // window events itself and re-reads the tree when fullscreen may change.
    property var fullscreenOutputs: []
    property bool treePending: false

    function refreshFullscreen(): void {
        if (!StatusbarSettings.autohide) {
            root.fullscreenOutputs = []
            return
        }
        if (treeProc.running)
            root.treePending = true
        else
            treeProc.running = true
    }

    Component.onCompleted: refreshFullscreen()

    Connections {
        target: StatusbarSettings
        function onAutohideChanged(): void { root.refreshFullscreen() }
    }

    I3IpcListener {
        subscriptions: ["window", "workspace", "output"]
        onIpcEvent: function (event) {
            if (event.type === "window") {
                let change = ""
                try { change = JSON.parse(event.data).change } catch (e) {}
                if (["fullscreen_mode", "close", "move"].indexOf(change) < 0)
                    return
            }
            root.refreshFullscreen()
        }
    }

    Process {
        id: treeProc
        command: ["i3-msg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                let outputs = []
                try {
                    outputs = root.fullscreenOutputsOf(JSON.parse(this.text))
                } catch (e) {
                    console.warn("statusbar: could not read the i3 tree:", e)
                }
                if (JSON.stringify(outputs) !== JSON.stringify(root.fullscreenOutputs))
                    root.fullscreenOutputs = outputs
            }
        }
        onExited: {
            if (root.treePending) {
                root.treePending = false
                treeProc.running = true
            }
        }
    }

    // Output names whose visible workspace holds a fullscreen container
    // (workspaces themselves always report fullscreen_mode 1, so only their
    // descendants count). Global fullscreen (mode 2) covers every output.
    function fullscreenOutputsOf(tree): var {
        let global = false
        function fullscreenIn(con) {
            let kids = (con.nodes || []).concat(con.floating_nodes || [])
            for (let i = 0; i < kids.length; i++) {
                if (kids[i].fullscreen_mode === 2)
                    global = true
                if (kids[i].fullscreen_mode > 0 || fullscreenIn(kids[i]))
                    return true
            }
            return false
        }
        let all = [], covered = []
        for (let out of (tree.nodes || [])) {
            if (out.type !== "output" || out.name.startsWith("__"))
                continue
            all.push(out.name)
            let content = (out.nodes || []).find(n => n.type === "con" && n.name === "content")
            if (!content || !content.focus || content.focus.length === 0)
                continue
            let ws = content.nodes.find(n => n.id === content.focus[0])
            if (ws && fullscreenIn(ws))
                covered.push(out.name)
        }
        return global ? all : covered
    }

    Variants {
        model: Quickshell.screens
        StatusbarWindow {
            required property var modelData
            screen: modelData
            fullscreenOutputs: root.fullscreenOutputs
        }
    }
}
