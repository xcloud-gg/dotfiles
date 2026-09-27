pragma Singleton

import Quickshell
import Quickshell.Io

// The status bar's settings file, its parsed contents, and the writes back
// into it -- plus the signals that route the focus/expand/collapse IPC calls
// to whichever monitor's bar instance is actually focused.
//
// This lives outside StatusbarWindow (mirrors DockApp/DockSettings.qml)
// because P2.4 made the window per-monitor (one instance per
// Quickshell.screens entry, via StatusbarLoader's Variants): the settings and
// the single "statusbar" IPC target have to be shared singletons, not
// per-instance, or every monitor would register its own competing
// IpcHandler for the same target name.
Singleton {
    id: root

    // Same two-file scheme as the dock:
    //
    //   1. ~/.config/xcloud-statusbar/statusbar.json — the user override. When
    //      this file EXISTS it is the master: every value is read from it and
    //      the Sidebar switches write their changes (enabled / alwaysExpanded)
    //      back into it. The shipped file is ignored while it exists.
    //   2. ~/.config/xcloud/settings/statusbar.json — the shipped fallback,
    //      used only when the override file is absent. It carries the dynamic
    //      state the SidebarApp writes (bar.enabled and bar.alwaysExpanded).
    //
    // The active master file is merged over the built-in defaults, so a
    // partial or entirely missing file still leaves every value defined.
    readonly property var defaultSettings: ({
        "bar":    { "height": 40, "reservedHeight": 72, "enabled": true,
                    "alwaysExpanded": true, "autohide": false, "hideDelay": 400 },
        "pill":   { "collapsedWidth": 0, "expandedWidth": 680, "radius": 12, "animationDuration": 350 },
        "modules":{ "left": ["terminal", "workspaces"],
                    "center": ["launcher", "clock", "swaync", "hypridle"],
                    "right": ["updates", "battery", "powerprofile", "volume", "systemtray", "logo", "power"] },
        "border": { "width": 2, "colorTop": "", "colorBottom": "" },
        "opacity":{ "collapsed": 0.6, "expanded": 0.8 },
        "clock":  { "format": "HH:mm", "dateFormat": "ddd, dd MMM" },
        "workspaces": { "count": 5 }
    })

    property var settings: defaultSettings

    readonly property int barHeight: settings.bar.height
    readonly property int reservedHeight: settings.bar.reservedHeight
    readonly property bool barEnabled: settings.bar.enabled
    readonly property bool alwaysExpanded: settings.bar.alwaysExpanded
    readonly property bool autohide: settings.bar.autohide

    // True while the user override file is present. Decides which file is the
    // master for both reads (applySettings) and writes (setEnabled /
    // setAlwaysExpanded / setAutohide).
    property bool overrideExists: false

    // Both settings files have reported back (loaded or missing), so
    // `settings` holds the values from disk rather than the built-in
    // defaults.
    //
    // Each StatusbarWindow instance stays invisible until then, so its layer
    // surface is created once with the values from disk. The files report
    // asynchronously, so without the gate a bar is mapped from the defaults —
    // autohide off, space reserved — and only corrects itself a moment later.
    // Hyprland does not reliably pick up the exclusive zone dropping back to
    // 0 that soon after the layer surface is created, which would leave an
    // autohiding bar holding a 52px gap open at the top of the screen for the
    // session.
    readonly property bool ready: overrideResolved && settingsResolved
    property bool overrideResolved: false
    property bool settingsResolved: false

    // User override / master file. When it loads it becomes the source of
    // truth; when it is absent (loadFailed) the shipped file takes over.
    // printErrors is off so a missing override does not log an error on every
    // startup/reload.
    FileView {
        id: overrideFile
        path: Quickshell.env("HOME") + "/.config/xcloud-statusbar/statusbar.json"
        blockLoading: true
        printErrors: false
        // The resolved flags are set last, after the values are in place:
        // they release the `ready` gate above, and a binding fires the moment
        // it is assigned.
        onLoaded: {
            root.overrideExists = true
            root.applySettings()
            root.overrideResolved = true
        }
        onLoadFailed: {
            root.overrideExists = false
            root.applySettings()
            root.overrideResolved = true
        }
    }

    // Shipped fallback holding the dynamic state (enabled / alwaysExpanded),
    // used only when the override file is absent. Changes are not picked up
    // automatically; trigger a re-read explicitly with
    //   qs ipc call statusbar reload
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/xcloud/settings/statusbar.json"
        blockLoading: true
        onLoaded: { root.applySettings(); root.settingsResolved = true }
        onLoadFailed: { root.applySettings(); root.settingsResolved = true }
    }

    // The active master file: the override when it exists, otherwise the
    // shipped file. The Sidebar switches write here and applySettings reads
    // from here.
    function masterFile() {
        return root.overrideExists ? overrideFile : settingsFile
    }

    // Force a re-read of both settings files and re-apply them. reload()
    // refreshes each FileView from disk (re-firing onLoaded/onLoadFailed,
    // which re-runs applySettings with an up-to-date overrideExists).
    function reloadSettings(): void {
        overrideFile.reload()
        settingsFile.reload()
        applySettings()
    }

    // Parse a settings JSON document that may contain a /* ... */ comment
    // block and — being hand-edited — trailing commas before a closing } or
    // ], which strict JSON.parse rejects. Returns the parsed object, or
    // undefined when the text is empty or cannot be parsed even after that
    // cleanup. Never throws.
    function parseSettings(src) {
        if (!src)
            return undefined
        let raw = src.replace(/\/\*[\s\S]*?\*\//g, "")
        if (raw.trim() === "")
            return undefined
        try {
            return JSON.parse(raw)
        } catch (e) {
            try {
                // Tolerate trailing commas: ",}" / ",]" (optional whitespace).
                return JSON.parse(raw.replace(/,(\s*[}\]])/g, "$1"))
            } catch (e2) {
                console.warn("statusbar settings: could not parse a file,"
                    + " ignoring it:", e2)
                return undefined
            }
        }
    }

    // Merge one JSON document (given as text) over an already-built settings
    // object, key by key. Empty or unparseable text is ignored so a
    // missing/partial file never clears previously merged values.
    function mergeSettings(merged, src): void {
        let parsed = parseSettings(src)
        if (parsed === undefined)
            return
        for (let group in parsed)
            for (let key in parsed[group])
                if (merged[group] !== undefined)
                    merged[group][key] = parsed[group][key]
    }

    // Rebuild the settings object: the built-in defaults with the master file
    // merged on top. An explicit masterText can be passed (e.g. right after a
    // switch writes the master file) so the merge does not depend on the
    // FileView buffer having refreshed yet.
    function applySettings(masterText): void {
        let merged = JSON.parse(JSON.stringify(root.defaultSettings))
        let text = (masterText !== undefined) ? masterText : root.masterFile().text()
        mergeSettings(merged, text)
        root.settings = merged
    }

    // Persist a bar.<key> boolean into the master file and return the
    // updated text. A regex replace is used when the key is already present
    // (so the file's formatting/comments are kept); when the key is missing
    // (e.g. an override file that did not list it) it falls back to a JSON
    // rewrite of the parsed document. If the file cannot be parsed at all the
    // write is skipped rather than replaced with an empty object, so a
    // malformed hand-edited override is never wiped — its current text is
    // returned unchanged.
    function persistBarFlag(key, on): string {
        let file = root.masterFile()
        let src = file.text()
        let re = new RegExp('("' + key + '"\\s*:\\s*)(true|false)')
        let updated
        if (re.test(src)) {
            updated = src.replace(re, "$1" + (on ? "true" : "false"))
        } else {
            let obj = root.parseSettings(src)
            if (obj === undefined && src && src.trim() !== "") {
                // Unparseable and non-empty: don't destroy the user's file.
                console.warn("statusbar settings: master file is not valid"
                    + " JSON; leaving it untouched instead of overwriting.")
                return src
            }
            if (typeof obj !== "object" || obj === null)
                obj = {}
            if (obj.bar === undefined)
                obj.bar = {}
            obj.bar[key] = on
            updated = JSON.stringify(obj, null, 4) + "\n"
        }
        file.setText(updated)
        return updated
    }

    function setEnabled(on: bool): void {
        applySettings(persistBarFlag("enabled", on))
    }

    function setAlwaysExpanded(on: bool): void {
        applySettings(persistBarFlag("alwaysExpanded", on))
    }

    function setAutohide(on: bool): void {
        applySettings(persistBarFlag("autohide", on))
    }

    // --- PER-MONITOR ROUTING ---
    // focus/expand/collapse are inherently per-instance (each monitor's bar
    // owns its own keyboard grab and expand/collapse state), so instead of
    // acting directly they fire a signal every StatusbarWindow instance
    // listens for; each instance ignores the request unless it is the one on
    // Hyprland's currently focused monitor (see StatusbarWindow's
    // monitorIsFocused, same pattern as overview/Overview.qml).
    signal focusRequested()
    signal expandToggleRequested()
    signal collapseRequested()
}
