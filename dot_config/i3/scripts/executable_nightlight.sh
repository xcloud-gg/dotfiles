#!/bin/sh
# SUPER+SHIFT+H: toggle the night light -- gammastep here, hyprsunset
# (xcloud-toggle-hyprsunset) on the Hyprland rice. The schedule and colour
# temperature are in ~/.config/gammastep/config.ini; gammastep resets the
# screen's gamma when it exits.
if pgrep -x gammastep >/dev/null; then
    pkill -x gammastep
    notify-send -a "Night light" -t 2000 "Night light off" 2>/dev/null
else
    setsid -f gammastep >/dev/null 2>&1
    notify-send -a "Night light" -t 2000 "Night light on" "07:00 day, 19:00 night" 2>/dev/null
fi
exit 0
