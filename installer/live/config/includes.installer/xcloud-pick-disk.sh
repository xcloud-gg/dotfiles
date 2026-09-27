#!/bin/sh
# partman/early_command (d-i, busybox sh): pick the OS disk and substitute it
# for @DISK@ in the expert_recipe. partman-auto/disk MUST be set for the LVM
# recipe to resolve (the real root cause of the "no physical volume defined in
# volume group" failure on thor, fixed in 12e2f46) — so it's never left unset.
#   1. `partman-auto/disk=/dev/X` on the kernel cmdline (the thor boot entry)
#   2. else the only non-removable, non-USB disk
#   3. else ask (debconf select)
. /usr/share/debconf/confmodule
log() { logger -t xcloud-pick-disk "$*"; }

disk=""
datadisk=""
for w in $(cat /proc/cmdline); do
    case "$w" in
        partman-auto/disk=*) disk=${w#*=} ;;
        xcloud.datadisk=*) datadisk=${w#*=} ;;
    esac
done

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
db_get partman-auto/expert_recipe
db_set partman-auto/expert_recipe "$(echo "$RET" | sed "s|@DISK@|$disk|g")"
exit 0
