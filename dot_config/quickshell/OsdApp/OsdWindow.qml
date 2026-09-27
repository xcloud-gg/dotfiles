import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.CustomTheme

// Native volume/mic/brightness on-screen-display. Driven entirely by IPC
// ("qs ipc call osd showVolume|showMic|showBrightness") from the XF86
// media-key binds in hypr/conf/keybindings/default.lua, which run the real
// wpctl/brightnessctl command first and then notify this window -- this
// window itself only reads back the resulting value to render, it never
// changes volume/brightness/mute state.
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore

    implicitWidth: 280
    implicitHeight: 64
    color: "transparent"

    anchors {
        bottom: true
    }
    // qmllint disable unresolved-type
    // PanelWindow's "margins" grouped property isn't in qmllint's bundled
    // QtQuick type info, so it always reports as unresolved - not a bug.
    margins {
        bottom: 90
    }
    // qmllint enable unresolved-type

    property bool showWindow: false
    visible: showWindow

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

    // Same wpctl/brightnessctl parsing already used by the sidebar's
    // volume/brightness sliders -- kept identical so the two never disagree.
    Process {
        id: volumeProc
        command: ["bash", "-c",
            "out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); " +
            "echo \"$out\" | awk '{print int($2 * 100)}'; " +
            "echo \"$out\" | grep -q MUTED && echo MUTED || echo UNMUTED"]
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
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo MUTED || echo UNMUTED"]
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

        RectangularShadow {
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
                        colorizationColor: Theme.primary
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.kind === "mic"
                    text: root.muted ? "🔇" : "🎤"
                    font.pixelSize: 16
                    color: Theme.primary
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
