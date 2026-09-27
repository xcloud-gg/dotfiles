#!/bin/sh
# Automatic screen dimming/locking on/off -- the X11 counterpart of the
# Hyprland rice's hypridle (hypridle.conf) and hypr/scripts/hypridle.sh.
# Started by the i3 config (`idle.sh on`) and toggled by the Quickshell bar's
# lock button (StatusbarApp/IdleModule.qml).
#
# Same timings as hypridle.conf:
#   8 min  dim the backlight (brightnessctl -s set 10, restored on activity)
#  10 min  lock (lock.sh)
#  11 min  screen off (DPMS)
#  before sleep: lock
# X screensaver: `xset s 480 120` activates it after 480 s idle, which makes
# xss-lock run the notifier (dim.sh); 120 s later (the "cycle") xss-lock runs
# the locker. --transfer-sleep-lock locks before suspend.
dir="$HOME/.config/i3/scripts"

start() {
    xset s 480 120
    xset dpms 0 0 660 +dpms
    pgrep -x xss-lock >/dev/null || \
        setsid -f xss-lock --transfer-sleep-lock -n "$dir/dim.sh" -- "$dir/lock.sh" >/dev/null 2>&1
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
