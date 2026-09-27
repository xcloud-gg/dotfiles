#!/bin/sh
# late.sh — runs at the end of the xCloud live-ISO install (d-i with
# live-installer), in the d-i environment (NOT chrooted — uses `in-target`
# where needed). Shipped in the ISO's d-i initrd (config/includes.installer/);
# nothing is fetched at install time. Derived from the netinst version,
# /opt/claude/baldr/installer/late.sh:
#  - same Btrfs reshape, but homes/logs are moved with the target's GNU mv
#  - the games/data disk is touched ONLY when `xcloud.datadisk=` is on the
#    kernel cmdline (the thor boot entry), never just because a disk exists
#  - Docker, dotfiles, lightdm, login shell: already in the image, sections removed
# If something below fails, `set -e` stops the script and d-i shows a red
# "late_command failed" dialog rather than continuing into a half-migrated system.
set -e

LOG=/tmp/xcloud-install.log
exec >"$LOG" 2>&1
echo "=== xcloud late.sh starting: $(date) ==="

# ---------------------------------------------------------------------------
# Capture device info while /target is still mounted normally, before we tear
# any of it down for the Btrfs reshape.
# ---------------------------------------------------------------------------
ROOT_DEV=$(awk '$2=="/target"{print $1; exit}' /proc/mounts)
BOOT_DEV=$(awk '$2=="/target/boot"{print $1; exit}' /proc/mounts)
ESP_DEV=$(awk '$2=="/target/boot/efi"{print $1; exit}' /proc/mounts)
[ -n "$ROOT_DEV" ] || { echo "FATAL: could not determine root device from /proc/mounts"; exit 1; }
echo "root=$ROOT_DEV boot=$BOOT_DEV esp=$ESP_DEV"

MOUNT_OPTS="compress=zstd:3,ssd,discard=async,noatime"
BTRFS_MNT=/mnt/xcloud-reshape
mkdir -p "$BTRFS_MNT"

# ---------------------------------------------------------------------------
# Reshape the single Btrfs volume partman created into subvolumes:
#   @        /
#   @home    /home
#   @log     /var/log
#   @docker  /var/lib/docker   (nodatacow — container storage)
#   @srv     /srv              (nodatacow — matches aios-thor-agent-prompt.md's
#                                /srv/aios/{models,adapters,datasets,presets,runs})
# partman-btrfs doesn't support custom subvolume recipes, so this is the
# standard (if fiddly) way to automate it: let partman install onto the plain
# top-level volume, then reshape here before first boot.
# ---------------------------------------------------------------------------
echo "--- unmounting /target tree for reshape ---"
umount /target/boot/efi 2>/dev/null || true
umount /target/boot 2>/dev/null || true
umount /target/dev 2>/dev/null || true
umount /target/proc 2>/dev/null || true
umount /target/sys 2>/dev/null || true
umount /target

echo "--- mounting top-level subvolume (id 5) ---"
mount -o subvolid=5 "$ROOT_DEV" "$BTRFS_MNT"

echo "--- snapshotting the installed tree into @ (not mv — mv is busybox here"
echo "    and a cross-subvolume mv of the whole system would silently drop"
echo "    xattrs/file capabilities via copy+delete; a snapshot is instant and"
echo "    exact) ---"
btrfs subvolume snapshot "$BTRFS_MNT" "$BTRFS_MNT/@"

echo "--- creating the other subvolumes empty ---"
for sv in @home @log @docker @srv; do
    btrfs subvolume create "$BTRFS_MNT/$sv"
done

echo "--- moving /home, /var/log, /srv, /var/lib/docker contents out of @ into"
echo "    their subvolumes, with the TARGET's GNU find/mv (chrooted into @): the"
echo "    image ships real homes (dotfiles, Zen, Claude Code), and busybox mv's"
echo "    cross-subvolume copy+delete isn't trusted with owner/mode/xattrs ---"
move_into_subvol() {  # $1 = directory inside @, $2 = subvolume name
    [ -d "$BTRFS_MNT/@$1" ] || return 0
    mkdir -p "$BTRFS_MNT/@/mnt/xcloud-sv"
    mount -o "subvol=$2" "$ROOT_DEV" "$BTRFS_MNT/@/mnt/xcloud-sv"
    chroot "$BTRFS_MNT/@" /usr/bin/find "$1" -mindepth 1 -maxdepth 1 \
        -exec /usr/bin/mv -t /mnt/xcloud-sv {} +
    umount "$BTRFS_MNT/@/mnt/xcloud-sv"
    rmdir "$BTRFS_MNT/@/mnt/xcloud-sv"
}
move_into_subvol /home @home
move_into_subvol /var/log @log
move_into_subvol /var/lib/docker @docker
move_into_subvol /srv @srv
mkdir -p "$BTRFS_MNT/@/home" "$BTRFS_MNT/@/var/log" "$BTRFS_MNT/@/var/lib/docker" \
         "$BTRFS_MNT/@/srv" "$BTRFS_MNT/@/boot" "$BTRFS_MNT/@/boot/efi"

umount "$BTRFS_MNT"

echo "--- remounting /target on the real subvolume layout ---"
mount -o "subvol=@,$MOUNT_OPTS" "$ROOT_DEV" /target
mkdir -p /target/home /target/var/log /target/var/lib/docker /target/srv \
         /target/boot /target/boot/efi /target/proc /target/sys /target/dev
mount -o "subvol=@home,$MOUNT_OPTS" "$ROOT_DEV" /target/home
mount -o "subvol=@log,$MOUNT_OPTS" "$ROOT_DEV" /target/var/log
mount -o "subvol=@docker,nodatacow,ssd,discard=async,noatime" "$ROOT_DEV" /target/var/lib/docker
mount -o "subvol=@srv,nodatacow,ssd,discard=async,noatime" "$ROOT_DEV" /target/srv
[ -n "$BOOT_DEV" ] && mount "$BOOT_DEV" /target/boot
[ -n "$ESP_DEV" ] && mount "$ESP_DEV" /target/boot/efi
mount --bind /dev /target/dev
mount --bind /proc /target/proc
mount --bind /sys /target/sys

echo "--- rewriting /etc/fstab with real UUIDs ---"
root_uuid=$(blkid -s UUID -o value "$ROOT_DEV")
boot_uuid=""
esp_uuid=""
[ -n "$BOOT_DEV" ] && boot_uuid=$(blkid -s UUID -o value "$BOOT_DEV")
[ -n "$ESP_DEV" ] && esp_uuid=$(blkid -s UUID -o value "$ESP_DEV")

cat > /target/etc/fstab <<FSTAB
# xcloud-generated fstab (installer/late.sh) — Btrfs subvolumes on LUKS2+LVM
UUID=$root_uuid / btrfs subvol=@,$MOUNT_OPTS 0 1
UUID=$root_uuid /home btrfs subvol=@home,$MOUNT_OPTS 0 2
UUID=$root_uuid /var/log btrfs subvol=@log,$MOUNT_OPTS 0 2
UUID=$root_uuid /var/lib/docker btrfs subvol=@docker,nodatacow,ssd,discard=async,noatime 0 2
UUID=$root_uuid /srv btrfs subvol=@srv,nodatacow,ssd,discard=async,noatime 0 2
FSTAB
[ -n "$boot_uuid" ] && echo "UUID=$boot_uuid /boot ext4 defaults 0 2" >> /target/etc/fstab
[ -n "$esp_uuid" ] && echo "UUID=$esp_uuid /boot/efi vfat umask=0077 0 1" >> /target/etc/fstab
cat /target/etc/fstab

echo "--- dm-crypt performance flags in crypttab (no_read/write_workqueue cuts"
echo "    a meaningful chunk of encryption overhead on fast NVMe + many-core"
echo "    CPUs; sector-size is luksFormat-time only and cryptsetup >=2.4"
echo "    already auto-detects 4K-native disks, so it's not set here) ---"
sed -i 's/luks$/luks,discard,no-read-workqueue,no-write-workqueue/' /target/etc/crypttab 2>/dev/null || true
cat /target/etc/crypttab 2>/dev/null || echo "(no /etc/crypttab found — unexpected for an encrypted install, check manually)"

echo "--- regenerating initramfs and GRUB for the new subvolume root ---"
in-target update-initramfs -u -k all
in-target update-grub

echo "--- verifying GRUB actually picked up the subvolume root before doing"
echo "    anything irreversible ---"
if ! grep -q 'rootflags=subvol=@' /target/boot/grub/grub.cfg; then
    echo "FATAL: grub.cfg does not reference rootflags=subvol=@ — stopping"
    echo "       before touching the old top-level tree. The install is left"
    echo "       in a recoverable but not-yet-bootable state; do not reboot"
    echo "       without investigating."
    exit 1
fi
echo "grub.cfg OK — rootflags=subvol=@ present"

echo "--- removing the now-redundant top-level copy ---"
# A snapshot doesn't remove its source: the ORIGINAL files are still also
# sitting at the raw top level (subvolid 5), duplicated (COW, so no extra
# space yet) inside @. Safe to clear now that grub.cfg is confirmed correct.
mount -o subvolid=5 "$ROOT_DEV" "$BTRFS_MNT"
for entry in "$BTRFS_MNT"/*; do
    name=$(basename "$entry")
    case "$name" in
        "@"|"@home"|"@log"|"@docker"|"@srv") continue ;;
    esac
    rm -rf "$entry"
done
umount "$BTRFS_MNT"
echo "=== Btrfs reshape complete ==="

# ---------------------------------------------------------------------------
# nvme0n1 — the second disk (2TB games/local storage), wiped and set up
# fresh (confirmed with the user; it's separate from the OS disk above and
# was never touched by partman — partman-auto/disk only lists nvme1n1).
# Plain Btrfs, no LUKS: full-disk encryption costs real throughput on a
# drive that's mostly game installs/large files, for no real security
# benefit over the encrypted OS disk it sits beside. Two subvolumes rather
# than one partition-per-purpose, so both can share the same pool of space
# instead of being split by a size guess up front.
# ---------------------------------------------------------------------------
DATA_DISK=""
OS_DISK=""
for w in $(cat /proc/cmdline); do
    case "$w" in
        xcloud.datadisk=*) DATA_DISK=${w#*=} ;;
        partman-auto/disk=*) OS_DISK=${w#*=} ;;
    esac
done
if [ -n "$DATA_DISK" ] && [ "$DATA_DISK" = "$OS_DISK" ]; then
    echo "FATAL: xcloud.datadisk ($DATA_DISK) is the OS disk — refusing"; exit 1
fi
if [ -n "$DATA_DISK" ] && [ -b "$DATA_DISK" ]; then
    echo "--- wiping and partitioning $DATA_DISK (games/data) ---"
    wipefs -af "$DATA_DISK"
    sfdisk "$DATA_DISK" <<SFDISK
label: gpt
,
SFDISK
    udevadm settle
    DATA_PART="${DATA_DISK}p1"
    [ -b "$DATA_PART" ] || DATA_PART="${DATA_DISK}1"

    echo "--- formatting $DATA_PART as btrfs, creating @games/@data ---"
    mkfs.btrfs -f -L games-data "$DATA_PART"
    mount "$DATA_PART" "$BTRFS_MNT"
    btrfs subvolume create "$BTRFS_MNT/@games"
    btrfs subvolume create "$BTRFS_MNT/@data"
    umount "$BTRFS_MNT"

    echo "--- mounting at /mnt/games and /mnt/data, owned by marius ---"
    DATA_OPTS="compress=zstd:3,noatime"
    mkdir -p /target/mnt/games /target/mnt/data
    mount -o "subvol=@games,$DATA_OPTS" "$DATA_PART" /target/mnt/games
    mount -o "subvol=@data,$DATA_OPTS" "$DATA_PART" /target/mnt/data
    data_uuid=$(blkid -s UUID -o value "$DATA_PART")
    {
        echo "UUID=$data_uuid /mnt/games btrfs subvol=@games,$DATA_OPTS 0 2"
        echo "UUID=$data_uuid /mnt/data btrfs subvol=@data,$DATA_OPTS 0 2"
    } >> /target/etc/fstab
    in-target chown marius:marius /mnt/games /mnt/data
    echo "=== games/data disk ready ==="
else
    echo "--- no xcloud.datadisk= on the cmdline (or device absent): data disk untouched ---"
fi

mkdir -p /target/var/log
cp "$LOG" /target/var/log/xcloud-install.log 2>/dev/null || true
echo "=== xcloud late.sh done: $(date) ==="
