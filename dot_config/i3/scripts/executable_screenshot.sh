#!/bin/sh
# X11 port of ~/.config/hypr/scripts/screenshot.sh (maim + xclip instead of
# grim/slurp/hyprshot). Same folder/filename as the Hyprland rice's settings.
#   screenshot.sh                 rofi menu (everything / active window / selection)
#   screenshot.sh --instant       full screen, no menu
#   screenshot.sh --instant-area  select an area, no menu
dir="$HOME/Pictures"
file="$dir/screenshot_$(date +%Y%m%d_%H%M%S).png"
mkdir -p "$dir"

case "$1" in
  --instant)      mode=full ;;
  --instant-area) mode=area ;;
  *)
    choice=$(printf 'Capture Everything\nCapture Active Window\nCapture Selection' |
      rofi -dmenu -i -no-show-icons -p "Take screenshot" -config ~/.config/rofi/config-i3.rasi) || exit 0
    case "$choice" in
      *Everything) mode=full ;;
      *Window)     mode=window ;;
      *Selection)  mode=area ;;
      *) exit 0 ;;
    esac
    ;;
esac

case "$mode" in
  full)   maim "$file" ;;
  window) maim -i "$(printf %d "$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $NF}')")" "$file" ;;
  area)   maim -s "$file" ;;
esac || exit 0

xclip -selection clipboard -t image/png -i "$file"
dunstify -a "Screen Capture" -i camera-photo-symbolic -t 1500 "Screenshot saved" "$file" 2>/dev/null || true
