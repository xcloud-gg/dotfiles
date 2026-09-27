import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
PanelWindow {
    id: root

    // The Hyprland monitor this instance is showing on, and whether it is
    // currently Hyprland's focused monitor -- used to decide whether this
    // instance should react to the focus/expand/collapse IPC calls, which
    // are broadcast to every instance (see the Connections block below).
    // Mirrors overview/modules/overview/Overview.qml's identical pattern.
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
    readonly property bool monitorIsFocused: Hyprland.focusedMonitor?.id === monitor?.id

    // --- WAYLAND CONFIGURATION ---
    WlrLayershell.layer: WlrLayer.Top
    // Keyboard focus is owned by the HyprlandFocusGrab below (the same primitive
    // the Calendar/Power popups use), not by the layer-shell focus mode. A
    // WlrKeyboardFocus.Exclusive grab held the keyboard until Escape and left
    // running apps dead; OnDemand never grabbed from the keybinding at all. The
    // focus grab gives the bar the keyboard while expanded *and* fires onCleared
    // when the pointer/keyboard goes to another window, which is what hands focus
    // back to the app (and collapses the bar). Leave the layer-shell mode at its
    // default (None) so the two mechanisms don't fight.

    // Grabs the keyboard for the bar while it is expanded so SUPER + ALT + SPACE can
    // drive Left/Right/Return navigation, and releases it the moment the user
    // interacts with another window (clicking/entering an app) — which returns
    // the keyboard to that app and collapses the bar.
    HyprlandFocusGrab {
        windows: [root]
        active: root.barExpanded
        onCleared: root.barExpanded = false
    }

    // --- USER SETTINGS ---
    // Settings loading/merging/persistence and the "statusbar" IPC target now
    // live in StatusbarSettings (a singleton) and StatusbarLoader
    // respectively -- see those files. This instance just binds to them.
    readonly property var settings: StatusbarSettings.settings
    readonly property bool ready: StatusbarSettings.ready

    readonly property int barHeight: StatusbarSettings.barHeight
    // Constant vertical space reserved for the bar (windows tile below this).
    readonly property int reservedHeight: StatusbarSettings.reservedHeight

    // Whether the bar is shown. The "enabled" flag in statusbar.json is the
    // single source of truth; it is toggled from the SidebarApp switch and via
    // "qs ipc call statusbar toggle", persisted back to the file, and survives
    // restarts. Kept as a binding so a settings reload updates it for free.
    readonly property bool barEnabled: StatusbarSettings.barEnabled

    // Hide completely and reserve no space when disabled. `ready` holds the
    // window back until the settings files have been read (see above).
    visible: barEnabled && ready
    // Reserve 20px less than the band so the gap below the pill is smaller
    // than above (windows tile 20px higher). An autohiding bar reserves nothing:
    // it floats over the windows and slides in on demand.
    exclusiveZone: (barEnabled && !autohide) ? reservedHeight - 20 : 0

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

    // --- AUTOHIDE ---
    // When "autohide" is set in statusbar.json the bar slides up out of the
    // screen and comes back only while the pointer is on it (or in the hot zone
    // at the very top of the screen), while it holds the keyboard for navigation
    // (SUPER + ALT + SPACE), and while a tray menu is open. A hiding bar reserves no
    // space, so windows tile up to the screen edge. Toggled from the SidebarApp
    // switch and via "qs ipc call statusbar autohideToggle".
    readonly property bool autohide: StatusbarSettings.autohide

    // React to the focus/expand/collapse IPC calls (routed via
    // StatusbarLoader's IpcHandler, since only one "statusbar" target can
    // exist -- see StatusbarSettings). Every instance receives the signal;
    // only the one on Hyprland's currently focused monitor acts on it.
    Connections {
        target: StatusbarSettings
        function onFocusRequested(): void {
            if (!root.monitorIsFocused)
                return
            root.barExpanded = true
            keyHandler.forceActiveFocus()
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

    // Slid into view when autohide is off, while the pointer is held on the bar,
    // while the bar is expanded for keyboard navigation, and while a tray menu is
    // open (the tray lives in the right area, which the reveal keeps on screen).
    readonly property bool revealed: !autohide || root.pointerHeld
        || root.barExpanded || root.trayMenuOpen

    // The pointer's hover, held for bar.hideDelay ms after it leaves. Without the
    // grace period the bar snaps shut on every momentary gap in the hover:
    // crossing from the hot zone down to the still-sliding pill, slipping between
    // the pill and the screen edge, or brushing past the edge of the pill.
    property bool pointerHeld: false

    Timer {
        id: hideDelay
        interval: root.settings.bar.hideDelay
        onTriggered: root.pointerHeld = false
    }

    HoverHandler {
        id: barHover
        onHoveredChanged: {
            if (barHover.hovered) {
                hideDelay.stop()
                root.pointerHeld = true
            } else {
                hideDelay.restart()
            }
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
    Component { id: cSwaync;     SwayncModule {} }
    Component { id: cHypridle;   HypridleModule {} }
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
    Component { id: cPowerProfile; PowerProfileModule {} }

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

    Component.onCompleted: Qt.callLater(rebuildNavItems)
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

    // qmllint disable unresolved-type
    // PanelWindow's "margins" grouped property isn't in qmllint's bundled
    // QtQuick type info, so it always reports as unresolved - not a bug.
    margins {
        top: 0
    }
    // qmllint enable unresolved-type

    implicitHeight: barHeight + 40

    // With autohide off the whole window takes pointer input, exactly as before.
    // While autohiding only the pill and a full-width strip at the top of the
    // screen do, so the rest of the band stays click-through and never swallows
    // clicks meant for the windows behind it: hidden the strip is the hot zone
    // that reveals the bar, revealed it bridges the gap above the pill. The strip
    // has to keep taking input after the reveal, or the pointer that triggered it
    // — still at the very top of the screen, and possibly nowhere near the pill
    // horizontally — would land outside the input region and hide the bar right
    // back again.
    readonly property int hotZoneHeight: root.revealed
        ? Math.max(3, Math.round(pill.y))
        : 3

    // Top edge of the pill, clamped to the window: while it is slid out its y is
    // negative, and a region may not start above the window.
    readonly property int pillTop: Math.max(0, Math.round(pill.y))

    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.autohide ? 0 : root.width
            height: root.autohide ? 0 : root.height
        }
        // The pill. While it is slid out this shrinks to nothing and the hot
        // zone below covers the sliver left at the screen edge.
        Region {
            x: Math.round(pill.x)
            y: root.pillTop
            width: root.autohide ? Math.round(pill.width) : 0
            height: root.autohide
                ? Math.max(0, Math.round(pill.y + pill.height) - root.pillTop)
                : 0
        }
        Region {
            x: 0
            y: 0
            width: root.autohide ? root.width : 0
            height: root.autohide ? root.hotZoneHeight : 0
        }
    }

    // ==========================================
    // CENTERED PILL
    // ==========================================
    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        // Center the pill within the reserved band. The window is taller than
        // the band (to fit the shadow / expanded pill), so offset accordingly.
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: revealedOffset + revealShift

        // Offset that centers the pill within the reserved band; the window is
        // taller than the band (to fit the shadow / expanded pill).
        readonly property real revealedOffset:
            (root.reservedHeight / 2) - (root.implicitHeight / 2)
        // Offset that leaves only a 3px sliver of the pill at the top of the
        // screen, i.e. slid fully out of view.
        readonly property real hiddenOffset:
            3 - height - (root.implicitHeight - height) / 2

        // The slide itself is animated as an extra shift rather than the whole
        // offset, so a change of the bar/pill height still repositions the pill
        // instantly instead of sliding it.
        property real revealShift: root.revealed
            ? 0
            : (hiddenOffset - revealedOffset)

        Behavior on revealShift {
            NumberAnimation {
                duration: root.settings.pill.animationDuration
                easing.type: Easing.OutQuint
            }
        }

        // Collapsed = sized to content, Expanded = fixed width.
        // While autohiding, the hover that reveals the bar also expands it: the
        // pointer that triggers the reveal sits in the hot zone at the screen
        // edge, above the pill, so hoverHandler alone would leave the bar slid in
        // but collapsed until the pointer reached the pill itself.
        property bool expanded: hoverHandler.hovered || root.barExpanded
            || root.alwaysExpanded || root.trayMenuOpen
            || (root.autohide && root.pointerHeld)
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

        RectangularShadow {
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
