#!/bin/sh
# Start picom with a backend that works on this machine. glx needs real GPU
# acceleration; in a VM (virtio/qxl without 3D) it composites stale frames,
# so windows look frozen/blurry and never update. xrender works everywhere
# but has no blur. Override with XCLOUD_PICOM_BACKEND=glx|xrender.
backend=${XCLOUD_PICOM_BACKEND:-}
if [ -z "$backend" ]; then
    if systemd-detect-virt --vm --quiet 2>/dev/null; then backend=xrender; else backend=glx; fi
fi
pkill -x picom 2>/dev/null
exec picom --config "$HOME/.config/picom/picom.conf" --backend "$backend"
