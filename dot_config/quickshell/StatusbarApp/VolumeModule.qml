import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.CustomTheme
import qs.StatusbarApp

// Shows the default output sink's volume next to a speaker icon.
//   • left click / Return   → open pavucontrol
//   • right click           → toggle mute
//   • mouse wheel (hovered)  → raise/lower the volume in 5% steps
//   • Up / Down arrows (keyboard-focused) → raise/lower the volume
// Volume and mute come from AudioState (pactl; the Hyprland version used the
// Pipewire service, which needs a PipeWire daemon).
Rectangle {
    id: volume

    readonly property bool ready: AudioState.ready
    readonly property bool muted: AudioState.muted
    readonly property int percent: muted ? 0 : AudioState.percent

    // How much one wheel notch / arrow press changes the volume (percent).
    readonly property int stepSize: 5

    // Set by the keyboard navigation in StatusbarWindow.
    property bool focused: false

    // Raise (dir > 0) or lower (dir < 0) the volume by one step. Called by the
    // mouse wheel and by the Up/Down keys when this module is keyboard-focused.
    function step(dir: int): void {
        if (ready)
            AudioState.setPercent(AudioState.percent + dir * stepSize)
    }

    // Right click: toggle mute. The sink keeps its volume while muted, so
    // un-muting restores exactly the level from before.
    function toggleMute(): void {
        if (ready)
            AudioState.toggleMute()
    }

    // Left click / keyboard Return: open the volume control GUI.
    function activate(): void {
        Quickshell.execDetached(["pavucontrol"])
    }

    readonly property bool active: mouseArea.containsMouse || volume.focused

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 30
    radius: 15

    // Same accent-filled highlight as the other modules on hover/selection.
    color: active ? Theme.primary : "transparent"

    // Fade the accent circle in/out like BarButton does.
    Behavior on color {
        ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Image {
            Layout.alignment: Qt.AlignVCenter
            source: volume.percent <= 0
                ? "../shared/icons/volume-muted.svg"
                : "../shared/icons/volume.svg"
            sourceSize.width: 18
            sourceSize.height: 18
            width: 18
            height: 18
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: volume.active ? Theme.background : Theme.on_surface
                Behavior on colorizationColor {
                    ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: volume.percent + "%"
            color: volume.active ? Theme.background : Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            Behavior on color {
                ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                volume.toggleMute()
            else
                volume.activate()
        }
        onWheel: wheel => volume.step(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
