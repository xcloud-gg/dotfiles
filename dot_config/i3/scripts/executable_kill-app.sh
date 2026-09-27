#!/bin/sh
# X11 port of Hyprland SUPER+SHIFT+Q: kill the process that owns the focused
# window (i.e. every window of that instance), not just the window itself.
win=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $NF}')
pid=$(xprop -id "$win" _NET_WM_PID 2>/dev/null | awk '{print $NF}')
case "$pid" in ''|*[!0-9]*) exit 0 ;; esac
kill "$pid"
