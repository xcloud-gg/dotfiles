#!/bin/sh
# xss-lock's notifier (see idle.sh): dim the backlight when the idle timer
# fires, like hypridle's 480 s listener. xss-lock kills this on activity (or
# once the screen locks), and the trap restores the saved brightness.
command -v brightnessctl >/dev/null 2>&1 || exec sleep infinity
brightnessctl -q -s set 10
sleep infinity &
pid=$!
trap 'kill "$pid" 2>/dev/null; brightnessctl -q -r; exit 0' TERM INT HUP
wait "$pid"
