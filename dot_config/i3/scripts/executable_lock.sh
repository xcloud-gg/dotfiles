#!/bin/sh
# Lock screen -- the X11 counterpart of the Hyprland rice's hyprlock: the
# blurred wallpaper (made by xcloud-wallpaper) behind the palette's colours
# (matugen -> ~/.config/i3/lock-colors.sh). Uses i3lock-color when it is
# installed (clock + user name bottom right, like hyprlock); Debian only
# packages plain i3lock, which gets the same image.
# -n: stay in the foreground, so xss-lock knows when the screen is unlocked.
cache="$HOME/.cache/xcloud/hyprland-dotfiles"
blurred="$cache/blurred_wallpaper.png"

LOCK_BACKGROUND=101418 LOCK_PRIMARY=9cd0ff LOCK_ON_PRIMARY=003351
LOCK_ON_SURFACE=e0e2e8 LOCK_ERROR=ffb4ab
[ -f "$HOME/.config/i3/lock-colors.sh" ] && . "$HOME/.config/i3/lock-colors.sh"

if command -v i3lock-color >/dev/null 2>&1; then
    img=""
    [ -f "$blurred" ] && img="--image=$blurred --fill"
    # shellcheck disable=SC2086 # $img is intentionally split into two args
    exec i3lock-color -n $img --color="$LOCK_BACKGROUND" \
        --inside-color="${LOCK_PRIMARY}ff" --ring-color="${LOCK_ON_PRIMARY}ff" \
        --insidever-color="${LOCK_PRIMARY}ff" --ringver-color="${LOCK_PRIMARY}ff" \
        --insidewrong-color="${LOCK_ERROR}ff" --ringwrong-color="${LOCK_ERROR}ff" \
        --line-color=00000000 --separator-color=00000000 \
        --keyhl-color="${LOCK_ON_PRIMARY}ff" --bshl-color="${LOCK_ERROR}ff" \
        --verif-color="${LOCK_ON_PRIMARY}ff" --wrong-color="${LOCK_ON_PRIMARY}ff" \
        --layout-color="${LOCK_ON_SURFACE}ff" \
        --time-color="${LOCK_PRIMARY}ff" --date-color="${LOCK_PRIMARY}ff" \
        --time-font="Fira Sans Semibold" --date-font="Fira Sans Semibold" \
        --verif-font="Fira Sans Semibold" --wrong-font="Fira Sans Semibold" \
        --clock --indicator --radius=60 --ring-width=6 \
        --time-str="%H:%M" --time-size=90 --time-align=2 --time-pos="w-50:h-50" \
        --date-str="$USER" --date-size=26 --date-align=2 --date-pos="w-50:h-150"
fi

# Plain i3lock draws a PNG unscaled from the top-left corner, so give it a
# copy of the blurred wallpaper cut to the current screen size (cached).
if [ -f "$blurred" ] && command -v magick >/dev/null 2>&1; then
    size=$(xrandr --current 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p')
    if [ -n "$size" ]; then
        fitted="$cache/blurred_wallpaper-$size.png"
        if [ ! -f "$fitted" ] || [ "$blurred" -nt "$fitted" ]; then
            magick "$blurred" -resize "$size^" -gravity center -extent "$size" "$fitted"
        fi
        [ -f "$fitted" ] && exec i3lock -n -i "$fitted" -c "$LOCK_BACKGROUND"
    fi
fi
if [ -f "$blurred" ]; then
    exec i3lock -n -i "$blurred" -c "$LOCK_BACKGROUND"
fi
exec i3lock -n -c "$LOCK_BACKGROUND"
