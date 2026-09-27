import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.CustomTheme

// Shows the active system power profile as an icon (leaf / gauge / rocket) and
// opens a small popup menu to switch between power-saver, balanced and
// performance. Reads and writes through Quickshell's PowerProfiles service,
// which is backed by power-profiles-daemon; no shell-out is needed. The module
// is always visible (unlike the battery module) so the profile can be changed
// both on battery and while plugged in.
Rectangle {
    id: profileRoot

    // Current profile as reported by power-profiles-daemon.
    readonly property int current: PowerProfiles.profile
    // Whether the daemon offers a performance profile (some machines don't).
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    // Whether the switch popup is open.
    property bool menuOpen: false
    // Set by the keyboard navigation in StatusbarWindow.
    property bool focused: false

    // The three selectable profiles, in ascending-power order. Performance is
    // dropped when the daemon does not expose it.
    readonly property var profiles: {
        let list = [
            { "value": PowerProfile.PowerSaver,  "label": "Power Saver",  "icon": "../shared/icons/profile-power-saver.svg" },
            { "value": PowerProfile.Balanced,    "label": "Balanced",     "icon": "../shared/icons/profile-balanced.svg" }
        ]
        if (hasPerformance)
            list.push({ "value": PowerProfile.Performance, "label": "Performance", "icon": "../shared/icons/profile-performance.svg" })
        return list
    }

    // Icon for the currently active profile, shown in the bar.
    readonly property string iconSource: {
        switch (current) {
        case PowerProfile.PowerSaver:   return "../shared/icons/profile-power-saver.svg"
        case PowerProfile.Performance:  return "../shared/icons/profile-performance.svg"
        default:                        return "../shared/icons/profile-balanced.svg"
        }
    }

    // Apply a profile and close the menu.
    function setProfile(value: int): void {
        PowerProfiles.profile = value
        profileRoot.menuOpen = false
    }

    // Mouse click / keyboard Return: toggle the switch popup.
    function activate(): void {
        profileRoot.menuOpen = !profileRoot.menuOpen
    }

    readonly property bool active: mouseArea.containsMouse || profileRoot.focused || profileRoot.menuOpen

    implicitWidth: 30
    implicitHeight: 30
    radius: 15

    // Same accent-filled circle as BarButton on hover/selection/open.
    color: active ? Theme.primary : "transparent"
    Behavior on color {
        ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
    }

    Image {
        anchors.centerIn: parent
        source: profileRoot.iconSource
        width: 18
        height: 18
        sourceSize.width: 18
        sourceSize.height: 18
        fillMode: Image.PreserveAspectFit
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: profileRoot.active ? Theme.background : Theme.primary
            Behavior on colorizationColor {
                ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: profileRoot.activate()
    }

    // ==========================================
    // SWITCH POPUP
    // ==========================================
    // Anchored just below the icon. On X11 a PopupWindow gets no keyboard and
    // no click-outside dismissal (see shell.qml), so instead of the Hyprland
    // focus grab it closes once the pointer has left it (after a short grace
    // period), on a second click on the icon, or after choosing a profile.
    PopupWindow {
        id: popup
        anchor.item: profileRoot
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 10
        // Anchor to the whole icon so Edges.Bottom is its bottom-center and
        // the Bottom gravity centers the popup under it. (Setting only
        // rect.x leaves a zero-size rect at the icon's top edge, which on X11
        // put the popup over the bar, shifted left by half its width.)
        anchor.rect.x: 0
        anchor.rect.y: 0
        anchor.rect.width: profileRoot.width
        anchor.rect.height: profileRoot.height

        visible: profileRoot.menuOpen

        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                if (popupHover.hovered) {
                    leaveTimer.stop()
                } else {
                    leaveTimer.interval = 600
                    leaveTimer.restart()
                }
            }
        }

        Timer {
            id: leaveTimer
            interval: 600
            onTriggered: profileRoot.menuOpen = false
        }

        implicitWidth: 220
        implicitHeight: menuColumn.implicitHeight + 16
        color: "transparent"

        // Opened but never entered (e.g. the pointer went straight back to
        // the bar): close after a while anyway.
        onVisibleChanged: {
            if (visible) {
                leaveTimer.interval = 3000
                leaveTimer.restart()
            }
        }

        // Card background, matching the sidebar's context menus: flat
        // background with a thin accent border.
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.background
            border.color: Theme.primary
            border.width: 1
        }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: profileRoot.profiles
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: modelData.value === profileRoot.current
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 4
                    color: rowMouse.containsMouse || selected ? Theme.primary : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutQuint }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Image {
                            Layout.alignment: Qt.AlignVCenter
                            source: modelData.icon
                            width: 16
                            height: 16
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: (rowMouse.containsMouse || selected) ? Theme.background : Theme.primary
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            text: modelData.label
                            color: (rowMouse.containsMouse || selected) ? Theme.background : Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: selected
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: profileRoot.setProfile(modelData.value)
                    }
                }
            }
        }
    }
}
