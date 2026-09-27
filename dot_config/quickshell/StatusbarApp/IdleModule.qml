import Quickshell
import Quickshell.Io
import QtQuick

// Toggles hypridle indefinitely -- the quickshell equivalent of the old
// waybar "custom/hypridle" module (same script, same plain on/off behavior,
// no timer). Same underlying toggle as the sidebar's Hypridle switch and
// Coffee Mode, so all three stay in sync regardless of which one is used.
BarButton {
    id: hypridleModule

    property bool hypridleActive: true

    iconSrc: "../shared/icons/lock.svg"
    opacity: hypridleActive ? 1.0 : 0.45
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    onClicked: {
        // Flip immediately for a responsive click; the next poll reconciles
        // with the real state in case the toggle script fails for some reason.
        hypridleModule.hypridleActive = !hypridleModule.hypridleActive
        Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/hypridle.sh toggle"])
    }

    Process {
        id: hypridleStateProc
        command: ["bash", "-c", "pgrep -x hypridle >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                hypridleModule.hypridleActive = (this.text.trim() === "1")
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: hypridleStateProc.running = true
    }
}
