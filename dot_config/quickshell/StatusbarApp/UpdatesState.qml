pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared pending-updates count and its "updates" IPC target.
//
// P2.4 made StatusbarWindow (and every module it places, UpdatesModule
// included) one instance per monitor via Variants. UpdatesModule used to own
// its own polling Process/Timer and its own `IpcHandler { target: "updates"
// }` directly -- fine for a single instance, but with N monitors N
// IpcHandlers now compete for the same target name (Quickshell logs "Handler
// was registered but will not be used" and drops all but one), and N
// separate processes would poll the same check script independently. Moved
// here, mirroring StatusbarSettings/StatusbarLoader: one poll, one IPC
// target, every UpdatesModule instance just reads `count`.
Singleton {
    id: root

    // Number of available updates (0 = nothing pending, modules hide).
    property int count: 0

    // Parse the script's JSON output ({"text": "69", ...}); an empty line
    // means zero updates and the script prints nothing.
    function refresh(): void {
        updatesProc.running = false
        updatesProc.running = true
    }

    Process {
        id: updatesProc
        command: ["bash", "-c",
            Quickshell.env("HOME") + "/.config/xcloud/scripts/xcloud-check-system-updates"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let raw = this.text.trim()
                    root.count = raw ? parseInt(JSON.parse(raw).text) || 0 : 0
                } catch (e) {
                    root.count = 0
                }
            }
        }
    }

    // Re-check on the same 1800s interval as the Waybar module.
    Timer {
        interval: 1800 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Let external scripts drive the module via `qs ipc call updates ...`.
    // `reset` clears the count immediately (e.g. right after an update run,
    // so every instance hides itself without waiting for the next poll);
    // `refresh` re-runs the check script on demand.
    IpcHandler {
        target: "updates"
        function reset(): void { root.count = 0 }
        function refresh(): void { root.refresh() }
    }
}
