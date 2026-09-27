#!/bin/sh
# Same as ~/.config/xcloud/scripts/xcloud-quicknote on the Hyprland side:
# one-line capture into today's daily note.
mkdir -p ~/.docs/daily
exec kitty --class quicknote -e bash -c '
    read -e -p "note: " line
    [ -n "$line" ] && printf "%s %s\n" "$(date +%H:%M)" "$line" >> ~/.docs/daily/"$(date +%F)".md
'
