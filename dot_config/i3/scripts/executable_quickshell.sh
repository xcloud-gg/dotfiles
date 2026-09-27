#!/bin/sh
# Start (or restart) the Quickshell shell -- run by the i3 config's
# exec_always and SUPER+SHIFT+B. `qs kill` stops the running instance first,
# so an i3 restart or the keybinding restarts the shell instead of stacking a
# second bar. Papirus-Dark: the Hyprland rice's kora icon theme isn't
# packaged in Debian. Logs: `qs log` (Quickshell keeps them itself).
qs kill >/dev/null 2>&1
QS_ICON_THEME=Papirus-Dark exec quickshell >/dev/null 2>&1
