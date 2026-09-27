#!/bin/sh
# Themed rofi powermenu (replaces wlogout on the Hyprland side)
options=" Lock\n Logout\n Suspend\n Reboot\n Shutdown"

chosen=$(printf "%b" "$options" | rofi -dmenu -i -p "power" -config ~/.config/rofi/config-i3-powermenu.rasi)

case "$chosen" in
  *Lock) ~/.config/i3/scripts/lock.sh ;;
  *Logout) i3-msg exit ;;
  *Suspend) ~/.config/i3/scripts/lock.sh & systemctl suspend ;;
  *Reboot) systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
esac
