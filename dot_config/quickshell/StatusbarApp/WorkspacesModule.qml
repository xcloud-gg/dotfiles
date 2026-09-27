import Quickshell.I3
import QtQuick
import QtQuick.Layouts
import qs.CustomTheme

// i3 workspace switcher. Workspaces are identified by their number: an
// I3Workspace's `id` is i3's container id, not the workspace number, and
// named workspaces without a number (number -1) are not shown.
RowLayout {
    id: wsRoot
    spacing: 6

    // Minimum number of workspaces to always display, even when empty. The list
    // still grows beyond this to reveal any higher-numbered workspace that
    // exists (e.g. switching to workspace 6 while this is 5 adds a 6th dot).
    property int minWorkspaces: 5

    // The individual workspace buttons, exposed so StatusbarWindow can splice
    // them into its keyboard-navigation list. Rebuilt whenever workspaces are
    // added or removed.
    property var navButtons: []

    function rebuildNavButtons(): void {
        let a = []
        for (let i = 0; i < rep.count; i++)
            a.push(rep.itemAt(i))
        wsRoot.navButtons = a
    }

    // The workspace ids to render: 1..N, where N is at least minWorkspaces and
    // extends to cover the highest-numbered workspace that currently exists.
    readonly property var workspaceIds: {
        let maxId = Math.max(1, wsRoot.minWorkspaces)
        const list = I3.workspaces.values
        for (let i = 0; i < list.length; i++)
            if (list[i].number > maxId)
                maxId = list[i].number
        let ids = []
        for (let id = 1; id <= maxId; id++)
            ids.push(id)
        return ids
    }

    // The live i3 workspace for a number, or null when it is empty (i3 only
    // keeps workspaces that hold windows or are visible on an output).
    function workspaceById(id: int): var {
        const list = I3.workspaces.values
        for (let i = 0; i < list.length; i++)
            if (list[i].number === id)
                return list[i]
        return null
    }

    Repeater {
        id: rep
        model: wsRoot.workspaceIds

        onItemAdded: wsRoot.rebuildNavButtons()
        onItemRemoved: wsRoot.rebuildNavButtons()

        delegate: Rectangle {
            id: ws
            required property var modelData   // the workspace id (int)
            // Set by StatusbarWindow's keyboard navigation.
            property bool focused: false

            // Whether this workspace is the currently focused one.
            readonly property bool isActive: I3.focusedWorkspace !== null
                && I3.focusedWorkspace.number === ws.modelData
            // Whether the workspace currently exists in i3 (holds windows or
            // is shown on an output).
            readonly property bool occupied: wsRoot.workspaceById(ws.modelData) !== null

            // Run this workspace's action (mouse click or keyboard Return).
            // Dispatched by number rather than via I3Workspace.activate() so
            // empty workspaces (no I3Workspace object yet) work too.
            function activate(): void {
                I3.dispatch("workspace number " + ws.modelData)
            }

            implicitWidth: 26
            implicitHeight: 26
            radius: 13

            // Empty, unfocused workspaces are dimmed to set them apart from the
            // ones that hold windows.
            opacity: (ws.isActive || ws.occupied || wsMouse.containsMouse) ? 1 : 0.45
            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
            }

            color: ws.isActive
                ? Theme.primary
                : (wsMouse.containsMouse ? Theme.surface_container_high : "transparent")
            border.color: Theme.primary
            border.width: ws.isActive ? 0 : 1

            // Crossfade the fill between active / hover / inactive states so the
            // background of the active circle fades in and the previous one out.
            Behavior on color {
                ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
            }
            // Fade the outline in/out as the fill takes over on activation.
            Behavior on border.width {
                NumberAnimation { duration: 500; easing.type: Easing.OutQuint }
            }

            // Keyboard-selection ring, distinct from the active-workspace fill.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: width / 2
                color: "transparent"
                border.color: Theme.primary
                border.width: 2
                opacity: ws.focused ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            Text {
                anchors.centerIn: parent
                text: ws.modelData
                color: ws.isActive ? Theme.background : Theme.on_background
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true

                // Match the fill crossfade so the label recolors in step.
                Behavior on color {
                    ColorAnimation { duration: 500; easing.type: Easing.OutQuint }
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ws.activate()
            }
        }
    }
}
