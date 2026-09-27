//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import "PowerApp"
import "SidebarApp"
import "CalendarApp"
import "StatusbarApp"
import "OsdApp"
import "LauncherApp"
import "CustomTheme"

// X11/i3 port of the xCloud Hyprland shell (Debian 13, Quickshell 0.3.1
// built without Wayland/Hyprland). How the Hyprland pieces map here:
//   - Only the status bar is a PanelWindow. On X11 every PanelWindow is an
//     i3 dock client, and i3 reserves the dock's WHOLE window height (it
//     ignores _NET_WM_STRUT) and only supports top/bottom docks.
//   - Power, Calendar, Launcher and Sidebar are FloatingWindows with a fixed
//     title ("xcloud-power", ...). i3 `for_window [title="^xcloud-..."]`
//     rules make them floating/borderless/sticky; each window positions
//     itself through I3.dispatch and closes when it loses focus (the
//     HyprlandFocusGrab replacement) or on Escape. A grabbing PopupWindow
//     is not used for these: on X11 it gets neither the keyboard nor
//     click-outside dismissal.
//   - The OSD is a non-grabbing PopupWindow anchored to the bar.
//   - Workspaces come from Quickshell.I3; volume from pactl (works with
//     PulseAudio and pipewire-pulse); notifications from dunst; idle/lock
//     from xss-lock.
// Not ported (left out on purpose): DockApp, WallpaperApp, WelcomeApp and
// the overview/ Hyprland workspace overview.
ShellRoot {
    // Test IPC tools: qs ipc show

    IpcHandler {
        target: "theme-manager"
        function reload(): void {
            Theme.reloadTheme()
        }
    }

    PowerWindow {}
    SidebarWindow {}
    CalendarWindow {}
    // Creates one StatusbarWindow per connected monitor and owns the single
    // "statusbar" IPC target.
    StatusbarLoader {}
    OsdWindow {}
    // Native launcher, toggled via `qs ipc call launcher toggle` -- see
    // ~/.config/i3/scripts/launcher.sh for the rofi/quickshell setting.
    LauncherWindow {}
}
