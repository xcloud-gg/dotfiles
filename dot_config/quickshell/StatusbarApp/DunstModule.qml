import Quickshell
import Quickshell.Io
import QtQuick

// Notifications button -- the dunst replacement for the Hyprland rice's
// SwayncModule (dunst has no notification-center panel). Shows a filled
// bell while notifications are on screen or queued, and dims while dunst is
// paused (do-not-disturb).
//   • left click  → re-show the most recent notification (history-pop)
//   • right click → pause/resume notifications
BarButton {
    id: dunst

    property bool hasNotifications: false
    property bool paused: false

    iconSrc: hasNotifications
        ? "../shared/icons/bell-filled.svg"
        : "../shared/icons/bell.svg"
    opacity: paused ? 0.45 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    onClicked: {
        Quickshell.execDetached(["dunstctl", "history-pop"])
        pollDelay.restart()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            dunst.paused = !dunst.paused
            Quickshell.execDetached(["dunstctl", "set-paused", "toggle"])
        }
    }

    // dunst has no event stream for this, so poll: displayed + waiting count
    // and the paused flag.
    Process {
        id: dunstProc
        command: ["sh", "-c",
            "echo $(( $(dunstctl count displayed 2>/dev/null || echo 0) + $(dunstctl count waiting 2>/dev/null || echo 0) )); " +
            "dunstctl is-paused 2>/dev/null || echo false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                dunst.hasNotifications = (parseInt(lines[0]) || 0) > 0
                dunst.paused = lines[1] === "true"
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: dunstProc.running = true
    }

    Timer {
        id: pollDelay
        interval: 300
        onTriggered: dunstProc.running = true
    }
}
