import Quickshell
import Quickshell.I3
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.CustomTheme
import qs.StatusbarApp

// One instance per connected monitor -- instantiated via Variants over
// Quickshell.screens in StatusbarLoader.qml (P2.4), which sets `screen` and
// declares the required `modelData` property. Settings and the "statusbar"
// IPC target are shared (StatusbarSettings, a singleton -- see that file and
// StatusbarLoader for why); barExpanded/keyboard-nav/hover stay local to each
// instance, since each monitor's bar should expand/collapse independently.
//
// X11/i3: this PanelWindow is an i3 dock client. i3 reserves the dock's
// whole window height (it ignores the strut / exclusiveZone), so the window
// is only as tall as the band the bar should reserve, and the autohide mode
// (a bar floating over the windows without reserving space) cannot exist
// here -- it is ignored. i3 never gives a dock client keyboard focus, so the
// SUPER + ALT + SPACE keyboard navigation is reduced to toggling the
// expanded state.
PanelWindow {
    id: root

    // The i3 output this instance is showing on, and whether it is currently
    // i3's focused output -- used to decide whether this instance should
    // react to the focus/expand/collapse IPC calls, which are broadcast to
    // every instance (see the Connections block below). Treated as focused
    // until the i3 IPC connection has reported the outputs.
    readonly property var monitor: I3.monitorFor(root.screen)
    readonly property bool monitorIsFocused: monitor ? monitor.focused : true

    // Register with StatusbarSettings so the OSD popup has a window to anchor
    // to (see StatusbarSettings.barWindow).
    Component.onCompleted: {
        StatusbarSettings.registerBar(root)
        Qt.callLater(rebuildNavItems)
    }
    Component.onDestruction: StatusbarSettings.unregisterBar(root)

    // --- USER SETTINGS ---
    // Settings loading/merging/persistence and the "statusbar" IPC target now
    // live in StatusbarSettings (a singleton) and StatusbarLoader
    // respectively -- see those files. This instance just binds to them.
    readonly property var settings: StatusbarSettings.settings
    readonly property bool ready: StatusbarSettings.ready

    readonly property int barHeight: StatusbarSettings.barHeight
    // Constant vertical space reserved for the bar (windows tile below this).
    readonly property int reservedHeight: StatusbarSettings.reservedHeight
    // Height of the dock window, which on i3 is also exactly the space i3
    // reserves. Hyprland reserved reservedHeight - 20 and let the (taller)
    // window overhang; here the window cannot overhang, so it is made a bit
    // taller than that to fit the expanded pill.
    readonly property int dockHeight: reservedHeight - 12

    // Whether the bar is shown. The "enabled" flag in statusbar.json is the
    // single source of truth; it is toggled from the SidebarApp switch and via
    // "qs ipc call statusbar toggle", persisted back to the file, and survives
    // restarts. Kept as a binding so a settings reload updates it for free.
    readonly property bool barEnabled: StatusbarSettings.barEnabled

    // Hide completely and reserve no space when disabled. `ready` holds the
    // window back until the settings files have been read (see above).
    visible: barEnabled && ready
    // Informational only on i3 (it reserves the whole window height anyway),
    // but keeps _NET_WM_STRUT honest for anything else reading it.
    exclusiveZone: dockHeight

    // Keep the pill expanded regardless of hover. Set on the focused monitor's
    // instance via IPC ("qs ipc call statusbar focus", bound to SUPER + ALT + SPACE
    // in Hyprland -- see the Connections block below) and cleared on Escape,
    // after running a module, or when the focus grab is released because the
    // user interacted with another window. Deliberately per-instance, not
    // read from StatusbarSettings: each monitor's bar expands/collapses for
    // keyboard nav independently of the others.
    property bool barExpanded: false

    // When set in statusbar.json the pill never collapses: it stays in its
    // expanded (full-width) state independent of hover or the IPC toggle. This
    // is purely visual — unlike barExpanded it does not grab the keyboard — so
    // the left/right module areas remain permanently visible.
    readonly property bool alwaysExpanded: StatusbarSettings.alwaysExpanded

    // React to the focus/expand/collapse IPC calls (routed via
    // StatusbarLoader's IpcHandler, since only one "statusbar" target can
    // exist -- see StatusbarSettings). Every instance receives the signal;
    // only the one on i3's currently focused output acts on it.
    Connections {
        target: StatusbarSettings
        // No keyboard on i3 (see the header comment): focus just toggles
        // the expanded state, like expand.
        function onFocusRequested(): void {
            if (root.monitorIsFocused)
                root.barExpanded = !root.barExpanded
        }
        function onExpandToggleRequested(): void {
            if (root.monitorIsFocused)
                root.barExpanded = !root.barExpanded
        }
        function onCollapseRequested(): void {
            if (root.monitorIsFocused)
                root.barExpanded = false
        }
    }

    // --- MODULE PLACEMENT ---
    // Each module name in the settings file maps to the component placed into
    // the left/center/right groups. Unknown names load nothing.
    Component { id: cTerminal;   TerminalModule {} }
    Component {
        id: cWorkspaces
        WorkspacesModule {
            minWorkspaces: root.settings.workspaces.count
        }
    }
    Component { id: cLauncher;   LauncherModule {} }
    Component {
        id: cClock
        ClockModule {
            expanded: pill.expanded
            timeFormat: root.settings.clock.format
            dateFormat: root.settings.clock.dateFormat
        }
    }
    // "swaync"/"hypridle" keep their Hyprland names in statusbar.json so the
    // same settings file works on both rices; here they are dunst and
    // xss-lock.
    Component { id: cSwaync;     DunstModule {} }
    Component { id: cHypridle;   IdleModule {} }
    // True while a system-tray context menu is open. Kept at window scope so
    // the pill can pin itself expanded while a menu is up (the tray lives in
    // the right area, which only exists while expanded).
    property bool trayMenuOpen: false
    Component {
        id: cSystemTray
        SystemTrayModule {
            // Rebuild keyboard navigation when the tray empties or repopulates
            // (it collapses out of the layout when it has no items).
            onCollapsedChanged: Qt.callLater(root.rebuildNavItems)
            // Surface the open-menu state up to the window so the pill stays
            // expanded for as long as a tray menu is showing.
            Binding {
                target: root
                property: "trayMenuOpen"
                value: menuOpen
            }
        }
    }
    Component { id: cLogo;       XcloudLogoModule {} }
    Component { id: cPower;      PowerModule {} }
    Component { id: cVolume;     VolumeModule {} }
    Component {
        id: cUpdates
        UpdatesModule {
            // Rebuild the keyboard navigation list when the module hides or
            // reappears (its collapsed state tracks the available update count).
            onCollapsedChanged: Qt.callLater(root.rebuildNavItems)
        }
    }
    Component {
        id: cBattery
        BatteryModule {
            // Rebuild the keyboard navigation list when the module hides or
            // reappears (it only shows while running on battery power).
            onCollapsedChanged: Qt.callLater(root.rebuildNavItems)
        }
    }
    // True while the power-profile popup is open: like a tray menu, it pins
    // the pill expanded, since the pointer leaving the bar for the popup
    // would otherwise collapse the right area and take the popup's anchor
    // with it.
    property bool profileMenuOpen: false
    Component {
        id: cPowerProfile
        PowerProfileModule {
            Binding {
                target: root
                property: "profileMenuOpen"
                value: menuOpen
            }
        }
    }

    readonly property var moduleComponents: ({
        "terminal":   cTerminal,
        "workspaces": cWorkspaces,
        "launcher":   cLauncher,
        "clock":      cClock,
        "swaync":     cSwaync,
        "hypridle":   cHypridle,
        "systemtray": cSystemTray,
        "logo":       cLogo,
        "power":      cPower,
        "updates":      cUpdates,
        "volume":       cVolume,
        "battery":      cBattery,
        "powerprofile": cPowerProfile
    })

    // --- KEYBOARD NAVIGATION ---
    // Ordered left-to-right list of the navigable items, rebuilt from the
    // placed modules whenever the layout or the (dynamic) workspace buttons
    // change. The workspace buttons are spliced in at the workspaces module's
    // position; collection modules without a single action (the system tray)
    // are skipped.
    property var navItems: []
    // Index of the keyboard-selected item, or -1 when none is selected.
    property int focusIndex: -1

    // The placed workspaces module, tracked so navItems can be rebuilt when its
    // button list changes (workspaces appear/disappear asynchronously).
    property var workspacesRef: null
    Connections {
        target: root.workspacesRef
        ignoreUnknownSignals: true
        function onNavButtonsChanged(): void { root.rebuildNavItems() }
    }

    function rebuildNavItems(): void {
        let items = []
        let ws = null
        let groups = [leftRepeater, centerRepeater, rightRepeater]
        for (let g = 0; g < groups.length; g++) {
            let rep = groups[g]
            for (let i = 0; i < rep.count; i++) {
                let loader = rep.itemAt(i)
                let m = loader ? loader.item : null
                if (!m)
                    continue
                if (m.collapsed === true)                // hidden (e.g. updates)
                    continue
                if (m.navButtons !== undefined) {        // workspaces
                    ws = m
                    items = items.concat(m.navButtons)
                } else if (typeof m.activate === "function") {
                    items.push(m)
                }
            }
        }
        root.workspacesRef = ws
        root.navItems = items
    }

    onSettingsChanged: Qt.callLater(rebuildNavItems)

    // Highlight exactly the item at focusIndex and clear all others. Called
    // both when the selection moves and when navItems changes underneath it.
    function applyFocus(): void {
        let items = root.navItems
        for (let i = 0; i < items.length; i++)
            items[i].focused = (i === root.focusIndex)
    }

    onFocusIndexChanged: applyFocus()
    onNavItemsChanged: {
        // Keep the selection in range when the workspace count changes.
        if (root.focusIndex >= root.navItems.length)
            root.focusIndex = root.navItems.length - 1
        applyFocus()
    }

    onBarExpandedChanged: {
        if (barExpanded) {
            focusIndex = 0
            keyHandler.forceActiveFocus()
        } else {
            focusIndex = -1
        }
    }

    function moveFocus(dir: int): void {
        if (!barExpanded)
            return
        let n = root.navItems.length
        root.focusIndex = (root.focusIndex + dir + n) % n
    }

    // Forward an Up/Down press to the keyboard-selected module if it exposes a
    // step() function (e.g. the volume module), so the arrows adjust it in place
    // without leaving keyboard-navigation mode.
    function stepFocused(dir: int): void {
        if (root.focusIndex < 0 || root.focusIndex >= root.navItems.length)
            return
        let m = root.navItems[root.focusIndex]
        if (typeof m.step === "function")
            m.step(dir)
    }

    function activateFocused(): void {
        if (root.focusIndex >= 0 && root.focusIndex < root.navItems.length)
            root.navItems[root.focusIndex].activate()
        // Collapse so the keyboard is handed back to the (possibly newly
        // launched) application instead of staying captured by the bar.
        root.barExpanded = false
    }

    color: "transparent"

    // Full-width strip anchored to the top of the screen
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: dockHeight

    // ==========================================
    // CENTERED PILL
    // ==========================================
    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        // Centered in the dock window (which is the reserved band on i3).
        anchors.verticalCenter: parent.verticalCenter

        // Collapsed = sized to content, Expanded = fixed width.
        property bool expanded: hoverHandler.hovered || root.barExpanded
            || root.alwaysExpanded || root.trayMenuOpen || root.profileMenuOpen
        // 0 in the settings file means "hug the center content".
        property real collapsedWidth: root.settings.pill.collapsedWidth > 0
            ? root.settings.pill.collapsedWidth
            : centerArea.implicitWidth + 32

        // Minimum width the content needs so the centered center area never
        // overlaps the left/right areas. The center stays centered, so each
        // side must clear half of it: the bar has to be at least as wide as the
        // center plus twice the wider of the two side areas (whichever side
        // would collide first), plus the 16px edge margins and some breathing
        // room. Computed live so adding workspaces (or any module growing)
        // pushes the bar wider instead of clipping.
        property real contentWidth: centerArea.implicitWidth
            + 2 * Math.max(leftArea.implicitWidth, rightArea.implicitWidth)
            + 64
        // expandedWidth from the settings file is treated as a minimum: the
        // pill grows past it when the content needs more room.
        property real expandedWidth: Math.max(
            root.settings.pill.expandedWidth, contentWidth)

        width: expanded ? expandedWidth : collapsedWidth
        height: expanded ? root.barHeight + 10 : root.barHeight

        Behavior on width {
            NumberAnimation {
                duration: root.settings.pill.animationDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.settings.pill.animationDuration
                easing.type: Easing.OutQuint
            }
        }

        HoverHandler {
            id: hoverHandler
        }

        // Captures arrow keys (navigate), Return (execute) and Escape
        // (collapse) while the bar is in expanded mode.
        FocusScope {
            id: keyHandler
            anchors.fill: parent
            focus: root.barExpanded
            Keys.onLeftPressed: root.moveFocus(-1)
            Keys.onRightPressed: root.moveFocus(1)
            Keys.onUpPressed: root.stepFocused(1)
            Keys.onDownPressed: root.stepFocused(-1)
            Keys.onReturnPressed: root.activateFocused()
            Keys.onEnterPressed: root.activateFocused()
            Keys.onEscapePressed: root.barExpanded = false
        }

        Shadow {
            anchors.fill: pillBg
            radius: pillBg.radius
            blur: 15
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.4)
        }

        // Gradient BORDER layer (outer)
        Rectangle {
            id: pillBg
            anchors.fill: parent
            radius: root.settings.pill.radius
            opacity: pill.expanded
                ? root.settings.opacity.expanded
                : root.settings.opacity.collapsed
            Behavior on opacity {
                NumberAnimation {
                    duration: root.settings.pill.animationDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Border colors come from the settings file; empty strings fall
            // back to the dynamic wallpaper theme.
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root.settings.border.colorTop !== ""
                        ? root.settings.border.colorTop
                        : Theme.primary
                }
                GradientStop {
                    position: 1.0
                    color: root.settings.border.colorBottom !== ""
                        ? root.settings.border.colorBottom
                        : Theme.on_primary
                }
            }

            // Actual background fill (inner), inset by the border thickness
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.settings.border.width
                radius: parent.radius - anchors.margins
                color: Theme.background
            }
        }

        // ==========================================
        // LEFT AREA (only visible when expanded)
        // ==========================================
        RowLayout {
            id: leftArea
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            opacity: pill.expanded ? 1 : 0
            visible: opacity > 0
            enabled: pill.expanded

            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }

            Repeater {
                id: leftRepeater
                model: root.settings.modules.left
                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: root.moduleComponents[modelData] || null
                    onLoaded: Qt.callLater(root.rebuildNavItems)
                }
            }
        }

        // ==========================================
        // CENTER AREA (always visible)
        // ==========================================
        RowLayout {
            id: centerArea
            anchors.centerIn: parent
            spacing: 14

            Repeater {
                id: centerRepeater
                model: root.settings.modules.center
                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: root.moduleComponents[modelData] || null
                    onLoaded: Qt.callLater(root.rebuildNavItems)
                }
            }
        }

        // ==========================================
        // RIGHT AREA (only visible when expanded)
        // ==========================================
        RowLayout {
            id: rightArea
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            opacity: pill.expanded ? 1 : 0
            visible: opacity > 0
            enabled: pill.expanded

            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }

            Repeater {
                id: rightRepeater
                model: root.settings.modules.right
                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    sourceComponent: root.moduleComponents[modelData] || null
                    // Collapse the layout slot when the module marks itself
                    // collapsed (e.g. the updates module with no pending
                    // updates). Reading the plain `collapsed` flag — rather than
                    // the module's effective `visible` — avoids a binding latch
                    // that would pin this Loader hidden once the right area
                    // collapses in the pill's collapsed state.
                    visible: (item && item.collapsed !== undefined) ? !item.collapsed : true
                    onLoaded: Qt.callLater(root.rebuildNavItems)
                }
            }
        }
    }
}
