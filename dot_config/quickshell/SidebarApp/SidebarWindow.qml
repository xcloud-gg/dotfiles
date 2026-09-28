import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.CustomTheme

// Reduced X11/i3 port of the Hyprland sidebar: screenshot button,
// volume/brightness sliders, MPRIS players, and the status bar / idle-lock
// switches plus the Qt theme tool. Left out because they have no Debian/i3
// counterpart in this rice: light/dark toggle and color picker (matugen,
// hyprpicker), Welcome/Settings/HyprMod buttons, status bar engine
// (waybar), autohide, dock, game mode, coffee mode, hyprsunset, fastfetch,
// wallpaper and the GTK theme tools (nwg-look).
// An OverlayWindow (i3 floating window, closes on focus loss) that slides in
// from the right edge below the bar, instead of a layer-shell overlay.
OverlayWindow {
    id: root
    title: "xcloud-sidebar"

    implicitWidth: 420 // 380 + 40
    // Full height of the output below the bar band (Hyprland: 52px margin).
    implicitHeight: Math.max(400, outputRect.height - 52)

    placement: function (out, w, h) {
        return { "x": out.x + out.width - w, "y": out.y + 52 }
    }

    // --- ESCAPE KEY LISTENER ---
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isOpen) {
                root.isOpen = false
            }
        }
    }

    // --- ANIMATION LOGIC ---
    keepMapped: slideAnim.running

    // Horizontal offset of the panel inside the window: 0 when open, pushed
    // past the window's right edge when closed.
    property real slideOffset: isOpen ? 0 : implicitWidth

    Behavior on slideOffset {
        NumberAnimation {
            id: slideAnim
            duration: 350
            easing.type: Easing.OutQuint
        }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void { root.isOpen = true }
        function close(): void { root.isOpen = false }
        function isOpen(): bool { return root.isOpen }
    }

    // --- REUSABLE COMPONENTS ---
    component XCloudMenuItem: MenuItem {
        id: control
        contentItem: Text {
            text: control.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            color: control.highlighted ? Theme.background : Theme.on_surface
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitWidth: 200
            implicitHeight: 36
            color: control.highlighted ? Theme.primary : "transparent"
            radius: 4
        }
    }

    component XCloudButton: Button {
        Layout.fillWidth: true
        background: Rectangle {
            color: "transparent"
            border.color: Theme.primary
            border.width: 1
            radius: 10
        }
        contentItem: Text {
            text: parent.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.on_surface
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            padding: 8
        }
    }

    component XCloudSwitch: Switch {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 48
        implicitHeight: 26
        indicator: Rectangle {
            implicitWidth: 48
            implicitHeight: 26
            radius: 13
            color: parent.checked ? Theme.primary : Theme.background
            border.color: Theme.primary
            border.width: 1
            Rectangle {
                x: parent.parent.checked ? parent.width - width - 2 : 2
                y: 2
                implicitWidth: 22
                implicitHeight: 22
                radius: 11
                color: parent.parent.checked ? Theme.background : Theme.on_surface_variant
                Behavior on x { NumberAnimation { duration: 150 } }
            }
        }
    }

    component SettingsWheel: Button {
        implicitWidth: 28
        implicitHeight: 28
        background: Rectangle { color: "transparent" }
        contentItem: Item {
            Image {
                anchors.centerIn: parent
                source: "../shared/icons/settings.svg"
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: Theme.on_surface
                }
            }
        }
    }

    // Supports text glyphs (iconTxt) for MPRIS controls and SVG files (iconSrc) for sidebar icons
    component ActionIcon: Button {
        property string iconTxt: ""
        property string iconSrc: ""
        implicitWidth: 28
        implicitHeight: 28
        background: Rectangle { color: "transparent" }
        contentItem: Item {
            Text {
                anchors.centerIn: parent
                text: iconTxt
                visible: iconSrc === ""
                color: Theme.on_surface
                font.family: "monospace"
                font.pixelSize: 18
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            Image {
                anchors.centerIn: parent
                source: iconSrc
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                visible: iconSrc !== ""
                fillMode: Image.PreserveAspectFit
                layer.enabled: iconSrc !== ""
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: Theme.on_surface
                }
            }
        }
    }

    // ==========================================
    // MAIN PANEL BACKGROUND
    // ==========================================
    Item {
        anchors.fill: parent
        anchors.margins: 20
        anchors.leftMargin: 20 + root.slideOffset
        anchors.rightMargin: 20 - root.slideOffset

        Shadow {
            id: shadow
            anchors.fill: mainBgRect
            radius: mainBgRect.radius
            blur: 15
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.4)
        }

        Rectangle {
            id: mainBgRect
            anchors.fill: parent
            radius: 10
            opacity: 0.95 // Only the background is transparent

            // Gradient border (outer)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.on_primary }
            }

            // Background fill (inner), inset by the border thickness
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: parent.radius - anchors.margins
                color: Theme.background
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            // --- TOP BAR (Screenshot) ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ActionIcon {
                    iconSrc: "../shared/icons/screenshot.svg"
                    onClicked: {
                        root.isOpen = false
                        Quickshell.execDetached(["sh", "-c", Quickshell.env("HOME") + "/.config/i3/scripts/screenshot.sh"])
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // --- SCROLLABLE CONTENT ---
            ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: mainContentColumn.implicitHeight // Tells ScrollView how tall the inner content truly is
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    interactive: true
                    contentItem: Rectangle {
                        implicitWidth: 6; radius: 3; color: Theme.primary
                        opacity: parent.pressed ? 1.0 : (parent.active ? 0.8 : 0.4)
                    }
                }

                ColumnLayout {
                    id: mainContentColumn
                    width: scrollView.width
                    spacing: 20

                    // --- SLIDERS (Loudness & Brightness) ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        // LOUDNESS SLIDER
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Image {
                                source: "../shared/icons/volume.svg"
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: Theme.on_surface
                                }
                            }

                            Slider {
                                id: volumeSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: 50 // Default

                                Process {
                                    command: ["sh", "-c", "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -n1 | tr -d '%'"]
                                    running: root.isOpen
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            let val = parseInt(this.text.trim())
                                            if (!isNaN(val)) volumeSlider.value = val;
                                        }
                                    }
                                }

                                onMoved: {
                                    Quickshell.execDetached(["pactl", "set-sink-volume", "@DEFAULT_SINK@", Math.round(value) + "%"])
                                }

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 6
                                    width: volumeSlider.availableWidth
                                    height: implicitHeight
                                    radius: 3
                                    color: Theme.background
                                    border.color: Theme.primary
                                    border.width: 1

                                    Rectangle {
                                        width: volumeSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: Theme.primary
                                        radius: 3
                                    }
                                }

                                handle: Rectangle {
                                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 8
                                    color: volumeSlider.pressed ? Theme.background : Theme.primary
                                    border.color: Theme.primary
                                    border.width: 1
                                }
                            }
                        }

                        // BRIGHTNESS SLIDER
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 15

                            Image {
                                source: "../shared/icons/brightness.svg"
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: Theme.on_surface
                                }
                            }

                            Slider {
                                id: brightnessSlider
                                Layout.fillWidth: true
                                from: 10 // Guaranteed Minimum 10%
                                to: 100
                                value: 100

                                Process {
                                    command: ["bash", "-c", "brightnessctl -m | awk -F, '{gsub(\"%\",\"\",$4); print $4}'"]
                                    running: root.isOpen
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            let val = parseInt(this.text.trim())
                                            if (!isNaN(val)) brightnessSlider.value = Math.max(10, val);
                                        }
                                    }
                                }

                                onMoved: {
                                    Quickshell.execDetached(["bash", "-c", "brightnessctl set " + Math.round(value) + "%"])
                                }

                                background: Rectangle {
                                    x: brightnessSlider.leftPadding
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 6
                                    width: brightnessSlider.availableWidth
                                    height: implicitHeight
                                    radius: 3
                                    color: Theme.background
                                    border.color: Theme.primary
                                    border.width: 1

                                    Rectangle {
                                        width: brightnessSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: Theme.primary
                                        radius: 3
                                    }
                                }

                                handle: Rectangle {
                                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 8
                                    color: brightnessSlider.pressed ? Theme.background : Theme.primary
                                    border.color: Theme.primary
                                    border.width: 1
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline_variant; Layout.topMargin: 5; Layout.bottomMargin: 5 }

                    // --- MPRIS PLAYERS (Scrollable ListView) ---
                    ListView {
                        id: mprisListView
                        Layout.fillWidth: true

                        // Dynamically scale based on players, up to 210px (max 2 players)
                        Layout.preferredHeight: contentHeight
                        Layout.maximumHeight: 210

                        spacing: 10
                        clip: true

                        model: Mpris.players.values
                        visible: Mpris.players.values.length > 0

                        // Force disable scrolling entirely unless there are 3+ players
                        interactive: mprisListView.count > 2

                        ScrollBar.vertical: ScrollBar {
                            // Explicitly hide the scrollbar unless there are 3+ players
                            policy: mprisListView.count > 2 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            interactive: true
                            contentItem: Rectangle {
                                implicitWidth: 6; radius: 3; color: Theme.primary
                                opacity: parent.pressed ? 1.0 : (parent.active ? 0.8 : 0.4)
                            }
                        }

                        delegate: Rectangle {
                            id: playerCard
                            property var player: modelData

                            width: mprisListView.width - 16
                            implicitHeight: 100

                            radius: 10
                            color: Theme.background
                            border.color: Theme.primary
                            border.width: 1
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 15

                                // Cover Art Block
                                Rectangle {
                                    implicitWidth: 80
                                    implicitHeight: 80
                                    radius: 8
                                    color: "transparent"
                                    border.color: Theme.primary
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: player.trackArtUrl ? player.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: player.trackArtUrl !== ""
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰝚" // Music note icon (fallback)
                                        font.family: "monospace"
                                        font.pixelSize: 32
                                        color: Theme.on_surface
                                        visible: !player.trackArtUrl || player.trackArtUrl === ""
                                    }
                                }

                                // Track Info & Controls
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 5

                                    Text {
                                        Layout.fillWidth: true
                                        text: player.trackTitle ? player.trackTitle : (player.identity ? player.identity : "No Media Playing")
                                        color: Theme.on_surface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            if (player.trackArtist) return player.trackArtist;
                                            if (player.trackArtists && player.trackArtists.length > 0) return player.trackArtists[0];
                                            return "Unknown Artist";
                                        }
                                        color: Theme.on_background
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        opacity: 0.8
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15

                                        Item { Layout.fillWidth: true }

                                        ActionIcon {
                                            iconTxt: "󰒮"
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            onClicked: player.previous()
                                        }

                                        ActionIcon {
                                            iconTxt: player.isPlaying ? "󰏤" : "󰐊"
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            onClicked: player.isPlaying = !player.isPlaying
                                        }

                                        ActionIcon {
                                            iconTxt: "󰒭"
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            onClicked: player.next()
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true;
                        implicitHeight: 1;
                        color: Theme.primary;
                        opacity: 0.3;
                        Layout.topMargin: 5;
                        Layout.bottomMargin: 5;
                        visible: Mpris.players.values.length > 0
                    }

                    // --- STATUS BAR ---
                    // Shows/hides the Quickshell status bar ("enabled" in the
                    // master statusbar.json, the same flag SUPER+CTRL+B flips).
                    // The Hyprland version also drives waybar; there is no
                    // waybar here.
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Status Bar"; color: Theme.on_surface; font.family: Theme.fontFamily; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        XCloudSwitch {
                            id: statusbarSwitch
                            property bool ready: false
                            Process {
                                id: statusbarStateProc
                                command: ["bash", "-c", "f=~/.config/xcloud-statusbar/statusbar.json; [ -f \"$f\" ] || f=~/.config/xcloud/settings/statusbar.json; grep -q '\"enabled\"[[:space:]]*:[[:space:]]*false' \"$f\" && echo 0 || echo 1"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        statusbarSwitch.checked = (this.text.trim() === "1")
                                        statusbarSwitch.ready = true
                                    }
                                }
                            }
                            // Re-read the state periodically while the sidebar is
                            // open so the switch tracks external toggles (e.g. the
                            // SUPER+CTRL+B keybinding) live, not just on reopen.
                            Timer {
                                interval: 1000
                                repeat: true
                                running: root.isOpen
                                triggeredOnStart: true
                                onTriggered: statusbarStateProc.running = true
                            }
                            onClicked: {
                                if (!ready) return;
                                Quickshell.execDetached(["qs", "ipc", "call", "statusbar",
                                    checked ? "enable" : "disable"])
                            }
                        }

                        SettingsWheel {
                            onClicked: statusbarMenu.open()
                            Menu {
                                id: statusbarMenu
                                y: parent.height
                                implicitWidth: 220
                                padding: 8

                                background: Rectangle { color: Theme.background; border.color: Theme.primary; border.width: 1; radius: 8 }
                                XCloudMenuItem { text: "Reload Status Bar"; onClicked: {
                                        // Re-read statusbar.json and apply it.
                                        Quickshell.execDetached(["qs", "ipc", "call", "statusbar", "reload"])
                                    }
                                }
                            }
                        }
                    }

                    // --- STATUSBAR ALWAYS EXPANDED (Quickshell) ---
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Statusbar Expanded"; color: Theme.on_surface; font.family: Theme.fontFamily; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        XCloudSwitch {
                            id: statusbarExpandedSwitch
                            property bool ready: false
                            // Read the current state from the "alwaysExpanded" flag
                            // in the master file: the xcloud-statusbar override when it
                            // exists, otherwise the shipped statusbar.json. A missing
                            // file or flag counts as off.
                            Process {
                                command: ["bash", "-c", "f=~/.config/xcloud-statusbar/statusbar.json; [ -f \"$f\" ] || f=~/.config/xcloud/settings/statusbar.json; grep -q '\"alwaysExpanded\"[[:space:]]*:[[:space:]]*true' \"$f\" && echo 1 || echo 0"]
                                running: root.isOpen
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        console.log("Test for Statusbar Expanded: " + this.text.trim())
                                        statusbarExpandedSwitch.checked = (this.text.trim() === "1")
                                        statusbarExpandedSwitch.ready = true
                                    }
                                }
                            }
                            onClicked: {
                                if (!ready) return;
                                // The statusbar owns the file write; just tell it
                                // the new state via IPC. `checked` already
                                // reflects the post-click position.
                                let ipcCmd = checked
                                ? "qs ipc call statusbar alwaysExpand"
                                : "qs ipc call statusbar autoCollapse"
                                console.log("Statusbar Expanded cmd: " + ipcCmd)
                                Quickshell.execDetached(["bash", "-c", ipcCmd])
                            }
                        }
                        Item { implicitWidth: 28 }
                    }

                    // --- AUTO LOCK (xss-lock) ---
                    // The i3 counterpart of the Hyprland "Hypridle" switch: same
                    // script as the bar's lock button (i3/scripts/idle.sh).
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Auto Lock"; color: Theme.on_surface; font.family: Theme.fontFamily; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        XCloudSwitch {
                            id: idleSwitch
                            property bool ready: false
                            // Purely a runtime toggle: xss-lock is started by the
                            // i3 config, so a re-login always brings it back.
                            Process {
                                id: idleStateProc
                                command: ["sh", "-c", "pgrep -x xss-lock >/dev/null && echo 1 || echo 0"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        idleSwitch.checked = (this.text.trim() === "1")
                                        idleSwitch.ready = true
                                    }
                                }
                            }
                            Timer {
                                interval: 1000
                                repeat: true
                                running: root.isOpen
                                triggeredOnStart: true
                                onTriggered: idleStateProc.running = true
                            }
                            onClicked: {
                                if (!ready) return;
                                Quickshell.execDetached(["sh", "-c", Quickshell.env("HOME") + "/.config/i3/scripts/idle.sh " + (checked ? "on" : "off")])
                            }
                        }
                        Item { implicitWidth: 28 }
                    }

                    // --- THEME ---
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Theme"; color: Theme.on_surface; font.family: Theme.fontFamily; font.pixelSize: 16 }
                        Item { Layout.fillWidth: true }
                        SettingsWheel {
                            onClicked: themeMenu.open()
                            Menu {
                                id: themeMenu
                                y: parent.height

                                implicitWidth: 220
                                padding: 8

                                background: Rectangle { color: Theme.background; border.color: Theme.primary; border.width: 1; radius: 8 }
                                XCloudMenuItem { text: "Set QT Theme"; onClicked: {
                                        root.isOpen = false
                                        Quickshell.execDetached(["qt6ct"])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
