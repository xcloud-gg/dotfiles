//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import "WelcomeApp"
import "PowerApp"
import "SidebarApp"
import "CalendarApp"
import "WallpaperApp"
import "StatusbarApp"
import "DockApp"
import "OsdApp"
import "LauncherApp"
import "CustomTheme"

ShellRoot {
    // Test IPC tools: qs ipc show

    IpcHandler {
        target: "theme-manager" 
        function reload(): void {
            Theme.reloadTheme()
        }
    }

    WelcomeWindow {}
    PowerWindow {}
    SidebarWindow {}
    CalendarWindow {}
    WallpaperWindow {}
    // Creates one StatusbarWindow per connected monitor (P2.4) and owns the
    // single "statusbar" IPC target.
    StatusbarLoader {}
    // Creates the dock window only while the dock is enabled in dock.json.
    DockLoader {}
    OsdWindow {}
    // P2.1: opt-in native launcher, toggled via `qs ipc call launcher toggle`
    // -- see launcher.sh for the rofi/quickshell setting branch.
    LauncherWindow {}
}