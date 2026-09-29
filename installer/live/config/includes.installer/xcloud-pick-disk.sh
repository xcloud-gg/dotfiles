#!/bin/sh
# partman/early_command (d-i, busybox sh): pick the OS disk and substitute it
# for @DISK@ in the expert_recipe. partman-auto/disk MUST be set for the LVM
# recipe to resolve (the real root cause of the "no physical volume defined in
# volume group" failure on thor, fixed in 12e2f46) — so it's never left unset.
#   1. `xcloud.osdisk=<model-substring>` on the cmdline (the thor boot entry):
#      resolved through /dev/disk/by-id, not the kernel's nvmeXn1 name — NVMe
#      enumeration order isn't guaranteed stable across boots/hardware (seen on
#      thor: disk roles came out swapped versus the boot entry's assumption).
#   2. else `partman-auto/disk=/dev/X` given directly (manual override/testing)
#   3. else the only non-removable, non-USB disk
#   4. else ask (debconf select)
# xcloud.datadisk= is resolved the same way (by-id if it looks like a model
# substring, else used as a literal /dev path) and the result is left at
# /tmp/xcloud-datadisk-resolved for late.sh, which runs later in this same
# live session (by-id resolution only needs to be stable within one boot).
. /usr/share/debconf/confmodule
log() { logger -t xcloud-pick-disk "$*"; }

resolve_by_id() {  # model substring -> /dev/nvmeXn1 (empty if not found/ambiguous)
    m=$1
    l=$(ls /dev/disk/by-id/ 2>/dev/null | grep -i "$m" | grep -v -- '-part[0-9]*$')
    n=$(printf '%s\n' "$l" | wc -l)
    [ "$n" = 1 ] && [ -n "$l" ] && readlink -f "/dev/disk/by-id/$l"
}

disk=""
datadisk=""
osmodel=""
for w in $(cat /proc/cmdline); do
    case "$w" in
        xcloud.osdisk=*) osmodel=${w#*=} ;;
        partman-auto/disk=*) disk=${w#*=} ;;
        xcloud.datadisk=*) datadisk=${w#*=} ;;
    esac
done

if [ -n "$osmodel" ]; then
    disk=$(resolve_by_id "$osmodel")
    [ -n "$disk" ] || log "WARNING: xcloud.osdisk=$osmodel did not resolve to exactly one /dev/disk/by-id entry; falling back"
fi
if [ -n "$datadisk" ]; then
    resolved=$(resolve_by_id "$datadisk")
    [ -n "$resolved" ] && datadisk=$resolved
    printf '%s\n' "$datadisk" > /tmp/xcloud-datadisk-resolved
fi

if [ -z "$disk" ]; then
    cands=""
    for d in $(list-devices disk); do
        n=${d##*/}
        [ "$(cat /sys/block/$n/removable 2>/dev/null)" = 1 ] && continue
        readlink -f /sys/block/$n | grep -q /usb && continue   # the live USB itself
        cands="$cands $d"
    done
    set -- $cands
    log "candidates:$cands"
    if [ $# -eq 1 ]; then
        disk=$1
    elif [ $# -gt 1 ]; then
        cat > /tmp/xcloud.templates <<TPL
Template: xcloud/disk
Type: select
Choices: \${choices}
Description: Disk to install on — it will be ERASED and encrypted:
 More than one internal disk was found. Pick the OS disk. Other disks are not touched.
TPL
        debconf-loadtemplate xcloud /tmp/xcloud.templates
        db_subst xcloud/disk choices "$(echo $cands | sed 's/ /, /g')"
        db_input critical xcloud/disk || true
        db_go
        db_get xcloud/disk; disk=$RET
    fi
fi

[ -b "$disk" ] || { log "FATAL: no usable disk (got '$disk')"; exit 1; }
[ -n "$datadisk" ] && [ "$datadisk" = "$disk" ] && { log "FATAL: data disk == OS disk ($disk)"; exit 1; }
log "OS disk: $disk; data disk: ${datadisk:-none}"

db_set partman-auto/disk "$disk"
# grub-installer otherwise picks the first disk (the data disk on thor). EFI
# installs mostly ignore the device, but BIOS/CSM would write it there.
db_set grub-installer/bootdev "$disk"
db_fset grub-installer/bootdev seen true
db_get partman-auto/expert_recipe
db_set partman-auto/expert_recipe "$(echo "$RET" | sed "s|@DISK@|$disk|g")"
exit 0
