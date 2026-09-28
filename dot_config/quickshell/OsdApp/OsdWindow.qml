import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.CustomTheme
import qs.StatusbarApp

// Native volume/mic/brightness on-screen-display. Driven entirely by IPC
// ("qs ipc call osd showVolume|showMic|showBrightness") from the XF86
// media-key binds in ~/.config/i3/config, which run the real
// pactl/brightnessctl command first and then notify this window -- this
// window itself only reads back the resulting value to render, it never
// changes volume/brightness/mute state.
//
// X11/i3: a non-grabbing PopupWindow (an override-redirect tooltip window
// that i3 does not manage and that never takes focus), anchored to the bar
// and placed bottom-center, 90px above the screen edge. It needs a visible
// bar to anchor to; with the bar disabled the OSD stays hidden.
PopupWindow {
    id: root

    readonly property var bar: StatusbarSettings.barWindow

    anchor.window: bar
    anchor.rect.x: bar ? Math.round((bar.width - implicitWidth) / 2) : 0
    anchor.rect.y: bar && bar.screen ? bar.screen.height - 90 - implicitHeight : 0

    implicitWidth: 280
    implicitHeight: 64
    color: "transparent"

    property bool showWindow: false
    visible: showWindow && bar !== null

    // "volume" | "mic" | "brightness"
    property string kind: "volume"
    property int percent: 0
    property bool muted: false

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.showWindow = false
    }

    function _show() {
        root.showWindow = true
        hideTimer.restart()
    }

    IpcHandler {
        target: "osd"
        function showVolume(): void {
            root.kind = "volume"
            volumeProc.running = true
        }
        function showMic(): void {
            root.kind = "mic"
            micProc.running = true
        }
        function showBrightness(): void {
            root.kind = "brightness"
            brightnessProc.running = true
        }
    }

    // pactl instead of wpctl (works with PulseAudio and pipewire-pulse) --
    // same parsing as StatusbarApp/AudioState.qml.
    Process {
        id: volumeProc
        command: ["sh", "-c",
            "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -n1 | tr -d '%'; " +
            "pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes && echo MUTED || echo UNMUTED"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                let val = parseInt(lines[0])
                root.percent = isNaN(val) ? 0 : Math.min(100, val)
                root.muted = lines[1] === "MUTED"
                root._show()
            }
        }
    }

    Process {
        id: micProc
        command: ["sh", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -q yes && echo MUTED || echo UNMUTED"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.muted = this.text.trim() === "MUTED"
                root._show()
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{gsub(\"%\",\"\",$4); print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(this.text.trim())
                root.percent = isNaN(val) ? 0 : val
                root._show()
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 10

        Shadow {
            id: shadow
            anchors.fill: bgRect
            radius: bgRect.radius
            blur: 15
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.4)
        }

        Rectangle {
            id: bgRect
            anchors.fill: parent
            radius: 14
            opacity: 0.95

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.on_primary }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: parent.radius - anchors.margins
                color: Theme.background
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22

                Image {
                    anchors.fill: parent
                    visible: root.kind !== "mic"
                    source: root.kind === "volume"
                        ? (root.muted ? "../shared/icons/volume-muted.svg" : "../shared/icons/volume.svg")
                        : "../shared/icons/brightness.svg"
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: Theme.on_surface
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.kind === "mic"
                    text: root.muted ? "🔇" : "🎤"
                    font.pixelSize: 16
                    color: Theme.on_surface
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.background
                border.color: Theme.primary
                border.width: 1
                visible: root.kind !== "mic"

                Rectangle {
                    width: parent.width * (root.percent / 100)
                    height: parent.height
                    radius: 3
                    color: Theme.primary
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.kind === "mic"
                text: root.muted ? "Microphone muted" : "Microphone unmuted"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.on_background
            }

            Text {
                visible: root.kind !== "mic"
                text: root.percent + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.on_background
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 40
            }
        }
    }
}
