#!/bin/bash
# build.sh — build the xCloud Debian 13 live ISO on loki (Arch), where live-build
# isn't packaged. Creates a Debian trixie "builder" chroot with Arch's debootstrap,
# installs live-build inside it, and runs `lb build` there. Safe to re-run: the
# builder chroot is reused, the live-build tree is cleaned each time.
#
# Usage: ./build.sh            (re-execs itself under sudo)
# Output: build/xcloud-live-amd64.iso
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$HERE/build
BUILDER=$WORK/builder              # Debian trixie chroot that runs live-build
TREE=$BUILDER/build                # the live-build working tree (auto/ + config/)
KIT=/opt/claude/xcloud/xcloud-agent-kit.tar.gz
OPKEY=$HERE/operator.pub           # marius's PUBLIC key -> bootstrap-host.sh --operator-key
SIGNER=$HERE/signer.pub           # optional: operator's git SIGNING public key -> firstboot verifies kit-* tags with it
MIRROR=http://deb.debian.org/debian

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
echo "MemAvailable: ${avail} MiB"
(( avail >= 700 )) || { echo "FATAL: under 700 MiB available — free RAM first" >&2; exit 1; }
[[ -f $KIT && -f $OPKEY ]] || { echo "FATAL: missing $KIT or $OPKEY" >&2; exit 1; }

mounts=(proc sys dev dev/pts)
cleanup() {
    for ((i=${#mounts[@]}-1; i>=0; i--)); do
        mountpoint -q "$BUILDER/${mounts[i]}" && umount -l "$BUILDER/${mounts[i]}"
    done
    return 0
}
trap cleanup EXIT

if [[ ! -x $BUILDER/usr/bin/lb ]]; then
    echo "--- creating builder chroot (debootstrap trixie) ---"
    mkdir -p "$WORK"
    debootstrap --variant=minbase --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
        trixie "$BUILDER" "$MIRROR"   # Arch: pacman -S debootstrap debian-archive-keyring
fi

mount -t proc proc "$BUILDER/proc"
mount --rbind /sys "$BUILDER/sys"; mount --make-rslave "$BUILDER/sys"
mount --bind /dev "$BUILDER/dev"
mount --bind /dev/pts "$BUILDER/dev/pts"
cp -L /etc/resolv.conf "$BUILDER/etc/resolv.conf"

if [[ ! -x $BUILDER/usr/bin/lb ]]; then
    chroot "$BUILDER" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin /bin/sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y live-build ca-certificates curl gpg'
fi

echo "--- syncing live-build config into the builder ---"
# keep $TREE/cache between builds (package downloads); everything else is fresh
find "$TREE" -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} + 2>/dev/null || true
mkdir -p "$TREE"
cp -a "$HERE/auto" "$HERE/config" "$TREE/"
# Inputs that don't belong in git: the agent kit (checked again in the hook) and
# the operator public key.
install -D -m 0600 "$KIT" "$TREE/config/includes.chroot/root/xcloud-agent-kit.tar.gz"
install -D -m 0644 "$OPKEY" "$TREE/config/includes.chroot/root/operator.pub"
if [[ -s $SIGNER ]]; then
    ssh-keygen -lf "$SIGNER" >/dev/null || { echo "FATAL: $SIGNER is not an SSH public key" >&2; exit 1; }
    install -D -m 0644 "$SIGNER" "$TREE/config/includes.chroot/usr/local/share/xcloud/signer.pub"
    echo "signer baked in: $(ssh-keygen -lf "$SIGNER")"
else
    echo "WARNING: no $SIGNER — first boot will use the baked agent kit only (no signed-kit path)" >&2
fi
chmod +x "$TREE"/auto/* "$TREE"/config/hooks/normal/*.hook.chroot

echo "--- lb build ---"
# mksquashfs is the RAM hog; loki has ~1-2 GiB headroom (see /opt/claude/CLAUDE.md).
chroot "$BUILDER" /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    MKSQUASHFS_OPTIONS="-processors 2 -mem 1G" \
    /bin/sh -c 'cd /build && lb clean && lb config && lb build' 2>&1 | tee "$WORK/build.log"
[[ ${PIPESTATUS[0]} -eq 0 ]] || { echo "FATAL: lb build failed — see $WORK/build.log" >&2; exit 1; }

iso=$(ls "$TREE"/*.iso 2>/dev/null | head -n1)
[[ -n $iso ]] || { echo "FATAL: no ISO produced — see $WORK/build.log" >&2; exit 1; }
mv "$iso" "$WORK/xcloud-live-amd64.iso"
chown -R --reference="$HERE" "$WORK/xcloud-live-amd64.iso" "$WORK/build.log"
ls -lh "$WORK/xcloud-live-amd64.iso"
