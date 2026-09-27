#!/bin/sh
# Application launcher (SUPER+SPACE and the bar's launcher button) -- port of
# the Hyprland rice's hypr/scripts/launcher.sh. rofi is the default; write
# "quickshell" to ~/.config/xcloud/settings/launcher to use the native
# Quickshell launcher instead.
launcher=$(cat "$HOME/.config/xcloud/settings/launcher" 2>/dev/null)

if [ "$launcher" = "quickshell" ]; then
    exec qs ipc call launcher toggle
fi
pkill -x rofi || exec rofi -show drun -replace -i -config "$HOME/.config/rofi/config-i3.rasi"
