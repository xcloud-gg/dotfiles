import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.CustomTheme

// Native application launcher, opt-in via ~/.config/xcloud/settings/launcher
// (value "quickshell") -- rofi stays the default; see
// ~/.config/i3/scripts/launcher.sh. Single instance, IPC toggle. The app list
// comes from Quickshell's own DesktopEntries singleton.
// X11/i3: an OverlayWindow (i3 floating window on the focused output, closes
// on focus loss) instead of a layer-shell overlay + HyprlandFocusGrab.
OverlayWindow {
    id: root
    title: "xcloud-launcher"

    // Horizontally centered, 18% down the focused output (same spot as the
    // Hyprland version's top margin).
    placement: function (out, w, h) {
        return { "x": out.x + (out.width - w) / 2, "y": out.y + Math.round(out.height * 0.18) }
    }

    property int selectedIndex: 0

    // No slide animation here unlike Power/Calendar -- a launcher wants to be
    // instantly there/gone, not draw attention sliding in.

    onIsOpenChanged: {
        if (isOpen) {
            searchField.text = ""
            root.selectedIndex = 0
        }
    }

    // The window only gets the keyboard once i3 has focused it.
    onHasFocusChanged: {
        if (hasFocus)
            searchField.forceActiveFocus()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void { root.isOpen = true }
        function close(): void { root.isOpen = false }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: root.isOpen = false
    }

    // Icon for a desktop entry: the entry's own icon name/path resolved
    // through the icon theme, falling back to a generic executable icon.
    // Same stripping DockApp/DockWindow.qml's iconFor does.
    function iconFor(entry: var): string {
        const raw = `${entry?.icon ?? ""}`.trim()
            .replace(/^image:\/\/icon\//, "").split("?")[0].trim()
        return Quickshell.iconPath(
            raw.length > 0 ? raw : "application-x-executable",
            "application-x-executable")
    }

    // Every real, launchable app (NoDisplay entries are deliberately hidden
    // -- that flag exists specifically so tools/helpers don't show up in
    // menus), sorted by name, filtered against the search field on name and
    // genericName (rofi drun matches both too).
    readonly property var filteredApps: {
        const query = searchField.text.trim().toLowerCase()
        const apps = DesktopEntries.applications.values
        let result = []
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            if (e.noDisplay)
                continue
            if (query.length > 0
                && !e.name.toLowerCase().includes(query)
                && !e.genericName.toLowerCase().includes(query))
                continue
            result.push(e)
        }
        result.sort((a, b) => a.name.localeCompare(b.name))
        return result
    }

    onFilteredAppsChanged: {
        if (root.selectedIndex >= filteredApps.length)
            root.selectedIndex = Math.max(0, filteredApps.length - 1)
    }

    function launch(entry: var): void {
        if (!entry)
            return
        entry.execute()
        root.isOpen = false
    }

    implicitWidth: 480
    implicitHeight: Math.min(520, list.contentHeight + searchRow.implicitHeight + 60)

    Shadow {
        anchors.fill: panelBg
        radius: panelBg.radius
        blur: 15
        color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.4)
    }

    // Gradient border (outer) + inset background (inner), same visual
    // language as PowerWindow/StatusbarWindow's pill.
    Rectangle {
        id: panelBg
        anchors.fill: parent
        radius: 20

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            id: searchRow
            Layout.fillWidth: true

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search apps…"
                color: Theme.primary
                font.pixelSize: 15
                padding: 8
                selectByMouse: true

                background: Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                    radius: 10
                    border.color: Theme.primary
                    border.width: 1
                }

                Keys.onDownPressed: root.selectedIndex = Math.min(
                    root.selectedIndex + 1, root.filteredApps.length - 1)
                Keys.onUpPressed: root.selectedIndex = Math.max(
                    root.selectedIndex - 1, 0)
                Keys.onReturnPressed: root.launch(root.filteredApps[root.selectedIndex])
                Keys.onEnterPressed: root.launch(root.filteredApps[root.selectedIndex])
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredApps
            currentIndex: root.selectedIndex
            highlightMoveDuration: 100

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: 44
                radius: 10
                color: index === root.selectedIndex
                    ? Theme.primary
                    : (rowMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent")

                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutQuint }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    Image {
                        Layout.alignment: Qt.AlignVCenter
                        source: root.iconFor(row.modelData)
                        sourceSize.width: 28
                        sourceSize.height: 28
                        width: 28
                        height: 28
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: index === root.selectedIndex ? Theme.background : Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(row.modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.filteredApps.length === 0
            text: "No matching apps"
            color: Theme.primary
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
