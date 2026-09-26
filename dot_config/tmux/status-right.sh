#!/usr/bin/env bash
# Status-right stats for .tmux.conf. Direct /proc and /sys reads only (no
# `top`/`ps` spawn) -- one call to this script per status-interval tick
# (tmux caches #() output between ticks, not per-render), so a single
# combined script here is cheaper than several separate #() calls.

load=$(cut -d' ' -f1 /proc/loadavg)
mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.0f", (t-a)/t*100}' /proc/meminfo)

battery=""
for bat in /sys/class/power_supply/BAT*; do
    [ -f "$bat/capacity" ] || continue
    battery="BAT $(cat "$bat/capacity")% | "
    break
done

printf '%sCPU %s MEM %s%%' "$battery" "$load" "$mem"
