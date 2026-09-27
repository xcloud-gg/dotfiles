import Quickshell
import Quickshell.Io
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

    Variants {
        model: Quickshell.screens
        StatusbarWindow {
            required property var modelData
            screen: modelData
        }
    }
}
