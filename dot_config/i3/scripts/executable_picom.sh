#!/bin/sh
# Start picom with a backend that works on this machine. glx needs real GPU
# acceleration; in a VM (virtio/qxl without 3D) it composites stale frames,
# so windows look frozen/blurry and never update. xrender works everywhere
# but has no blur. Override with XCLOUD_PICOM_BACKEND=glx|xrender.
backend=${XCLOUD_PICOM_BACKEND:-}
if [ -z "$backend" ]; then
    if systemd-detect-virt --vm --quiet 2>/dev/null; then backend=xrender; else backend=glx; fi
fi

# kitty's background_opacity 0.7 (kitty.conf, as on Hyprland) is made for a
# blurred background. Without blur (xrender) the wallpaper shows through
# sharp, so kitty gets 0.9 there. A picom opacity rule can't do this: it
# multiplies the whole window, text included, and can only lower kitty's own
# alpha, never raise it. Applies to kitty windows opened after this runs.
kitty_conf="$HOME/.config/kitty/backend-opacity.conf"
{
    echo "# Written by ~/.config/i3/scripts/picom.sh at every i3 start -- do not edit."
    [ "$backend" = xrender ] && echo "background_opacity 0.9"
} > "$kitty_conf"

pkill -x picom 2>/dev/null
exec picom --config "$HOME/.config/picom/picom.conf" --backend "$backend"
