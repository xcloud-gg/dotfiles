#!/bin/sh
# Start picom with a backend that works on this machine. glx needs real GPU
# acceleration; on a software renderer (llvmpipe/softpipe -- e.g. a VM without
# virgl 3D) it composites stale frames, so windows look frozen/blurry and never
# update. xrender works everywhere but has no blur. A VM with virtio-gpu 3D
# (virgl) is a real GL renderer and gets glx + blur like bare metal.
# Override with XCLOUD_PICOM_BACKEND=glx|xrender.
backend=${XCLOUD_PICOM_BACKEND:-}
if [ -z "$backend" ]; then
    renderer=$(glxinfo -B 2>/dev/null | sed -n 's/^OpenGL renderer string: //p')
    case "$renderer" in
        *llvmpipe*|*softpipe*|*"Software Rasterizer"*) backend=xrender ;;
        "") # no glxinfo: fall back to "VM means software GL"
            if systemd-detect-virt --vm --quiet 2>/dev/null; then backend=xrender; else backend=glx; fi ;;
        *) backend=glx ;;
    esac
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
