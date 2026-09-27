pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Default output sink volume/mute via pactl -- the X11 replacement for
// Quickshell.Services.Pipewire, which needs a PipeWire daemon. pactl talks to
// PulseAudio and to pipewire-pulse alike, so this works whichever sound
// server the image runs. `pactl subscribe` pushes change events; each one
// (debounced) re-reads the sink. A singleton so every per-monitor bar shares
// one subscription.
Singleton {
    id: root

    // False until the first successful read (no sound server -> stays false).
    property bool ready: false
    property int percent: 0
    property bool muted: false

    function refresh(): void {
        query.running = false
        query.running = true
    }

    // Absolute volume in percent (0-100), unmuting first so a scroll/arrow
    // while muted brings the sound back.
    function setPercent(p: int): void {
        const v = Math.max(0, Math.min(100, Math.round(p)))
        Quickshell.execDetached(["sh", "-c",
            "pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ " + v + "%"])
        root.percent = v
        root.muted = false
    }

    function toggleMute(): void {
        Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        root.muted = !root.muted
    }

    // Line 1: volume of the first channel in percent; line 2: "Mute: yes|no".
    Process {
        id: query
        command: ["sh", "-c",
            "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -n1 | tr -d '%'; " +
            "pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const val = parseInt(lines[0])
                if (isNaN(val)) {
                    root.ready = false
                    return
                }
                root.percent = val
                root.muted = (lines[1] || "").indexOf("yes") >= 0
                root.ready = true
            }
        }
    }

    Process {
        id: subscriber
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("sink") >= 0 || data.indexOf("server") >= 0)
                    debounce.restart()
            }
        }
        // No sound server yet (or it restarted): try again shortly.
        onExited: respawn.start()
    }

    Timer {
        id: debounce
        interval: 60
        onTriggered: root.refresh()
    }

    Timer {
        id: respawn
        interval: 5000
        onTriggered: {
            subscriber.running = true
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
