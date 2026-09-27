#!/bin/sh
# Automatic screen locking on/off -- the X11 counterpart of the Hyprland
# rice's hypr/scripts/hypridle.sh. xss-lock (started by the i3 config) locks
# with lock.sh when the X screensaver kicks in; stopping it (and blanking) is
# the equivalent of stopping hypridle. Used by the Quickshell bar's lock
# button (StatusbarApp/IdleModule.qml).
start() {
    xset s on +dpms
    pgrep -x xss-lock >/dev/null || \
        setsid -f xss-lock -- "$HOME/.config/i3/scripts/lock.sh" >/dev/null 2>&1
}
stop() {
    pkill -x xss-lock
    xset s off -dpms
}
case "$1" in
    on) start ;;
    off) stop ;;
    toggle|"") if pgrep -x xss-lock >/dev/null; then stop; else start; fi ;;
    *) echo "usage: $0 [on|off|toggle]" >&2; exit 1 ;;
esac
