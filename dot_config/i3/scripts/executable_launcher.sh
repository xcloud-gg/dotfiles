#!/bin/sh
# Application launcher (SUPER+SPACE and the bar's launcher button) -- port of
# the Hyprland rice's hypr/scripts/launcher.sh. rofi is the default; write
# "quickshell" to ~/.config/xcloud/settings/launcher to use the native
# Quickshell launcher instead.
# rofi uses the same config.rasi as on Hyprland (blurred wallpaper panel from
# xcloud-wallpaper's current_wallpaper.rasi); until that file exists, the
# self-contained config-i3.rasi.
launcher=$(cat "$HOME/.config/xcloud/settings/launcher" 2>/dev/null)

if [ "$launcher" = "quickshell" ]; then
    exec qs ipc call launcher toggle
fi
config="$HOME/.config/rofi/config.rasi"
[ -f "$HOME/.cache/xcloud/hyprland-dotfiles/current_wallpaper.rasi" ] || config="$HOME/.config/rofi/config-i3.rasi"
pkill -x rofi || exec rofi -show drun -replace -i -config "$config"
