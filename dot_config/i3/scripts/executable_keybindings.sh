#!/bin/sh
# X11 port of ~/.config/hypr/scripts/keybindings.sh: list the i3 bindings in rofi.
grep -E '^\s*bindsym' ~/.config/i3/config | sed -e 's/^\s*bindsym\s*//' -e 's/\$mod/SUPER/g' |
  rofi -dmenu -i -p "Keybinds" -config ~/.config/rofi/config-i3.rasi >/dev/null
