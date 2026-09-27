import Quickshell
import Quickshell.Io
import QtQuick

// Toggles automatic screen locking -- the X11 equivalent of the Hyprland
// rice's hypridle module. On i3 the idle locker is xss-lock (started from the
// i3 config); ~/.config/i3/scripts/idle.sh stops/starts it, the way
// hypr/scripts/hypridle.sh toggles hypridle. Dimmed while it is off.
BarButton {
    id: idleModule

    property bool idleActive: true

    iconSrc: "../shared/icons/lock.svg"
    opacity: idleActive ? 1.0 : 0.45
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    onClicked: {
        // Flip immediately for a responsive click; the next poll reconciles
        // with the real state in case the toggle script fails for some reason.
        idleModule.idleActive = !idleModule.idleActive
        Quickshell.execDetached(["sh", "-c", Quickshell.env("HOME") + "/.config/i3/scripts/idle.sh toggle"])
    }

    Process {
        id: idleStateProc
        command: ["sh", "-c", "pgrep -x xss-lock >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                idleModule.idleActive = (this.text.trim() === "1")
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: idleStateProc.running = true
    }
}
