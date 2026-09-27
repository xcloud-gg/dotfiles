import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.I3

// Base for the Power/Calendar/Launcher/Sidebar overlays on X11/i3 -- the
// replacement for their Hyprland PanelWindow (layer-shell overlay) +
// HyprlandFocusGrab setup.
//
// A FloatingWindow with a fixed `title`; the i3 config's
//   for_window [title="^xcloud-(power|calendar|launcher|sidebar)$"]
//       floating enable, border pixel 0, sticky enable
// makes it a borderless floating window, and i3 focuses it when it maps.
// Once mapped it moves itself to `placement` on i3's focused output (i3
// centers it until then). It closes when it loses focus -- clicking or
// pointing (focus_follows_mouse) at another window -- which is what the
// Hyprland focus grab's onCleared did.
FloatingWindow {
    id: overlay

    property bool isOpen: false
    // Keep the window mapped after isOpen went false, e.g. while a close
    // animation is still running.
    property bool keepMapped: false

    // (output rect, width, height) -> {x, y} in root-window coordinates.
    // Default: centered on the output.
    property var placement: function (out, w, h) {
        return { "x": out.x + (out.width - w) / 2, "y": out.y + (out.height - h) / 2 }
    }

    // True once the window has actually received focus after this map --
    // only a loss of focus after that closes it.
    property bool wasActive: false
    readonly property bool hasFocus: focusProbe.active

    color: "transparent"
    visible: isOpen || keepMapped

    // The focused output's geometry, falling back to the first screen while
    // the i3 IPC connection has not reported the outputs.
    readonly property var outputRect: {
        const m = I3.focusedMonitor
        if (m && m.width > 0)
            return { "x": m.x, "y": m.y, "width": m.width, "height": m.height }
        const s = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        return s ? { "x": s.x, "y": s.y, "width": s.width, "height": s.height }
                 : { "x": 0, "y": 0, "width": 1920, "height": 1080 }
    }

    function place(): void {
        const p = overlay.placement(overlay.outputRect, overlay.implicitWidth, overlay.implicitHeight)
        I3.dispatch("[title=\"^" + overlay.title + "$\"] move position "
            + Math.round(p.x) + " px " + Math.round(p.y) + " px")
    }

    onVisibleChanged: {
        if (visible) {
            overlay.wasActive = false
            // i3 has to manage the window before the move can match it; the
            // retry covers a map that is still in flight on the first try.
            Qt.callLater(overlay.place)
            placeRetry.restart()
        }
    }

    Timer {
        id: placeRetry
        interval: 120
        onTriggered: overlay.place()
    }

    Item {
        id: focusProbe
        readonly property bool active: Window.active
        onActiveChanged: {
            if (active)
                overlay.wasActive = true
            else if (overlay.wasActive && overlay.isOpen)
                overlay.isOpen = false
        }
    }
}
