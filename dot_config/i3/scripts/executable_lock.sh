#!/bin/sh
# i3lock-color themed to match the xcloud rice. Debian only packages plain
# i3lock, so fall back to it (solid rice background) when i3lock-color is absent.
if ! command -v i3lock-color >/dev/null 2>&1; then
  exec i3lock -c 0c1609
fi
exec i3lock-color \
  --insidever-color=182214ff \
  --insidewrong-color=ffb4abff \
  --inside-color=0c1609ff \
  --ringver-color=68e054ff \
  --ringwrong-color=ffb4abff \
  --ring-color=3b4b35ff \
  --line-color=0c1609ff \
  --separator-color=00000000 \
  --verif-color=d9e7d0ff \
  --wrong-color=ffb4abff \
  --time-color=d9e7d0ff \
  --date-color=d9e7d0ff \
  --layout-color=d9e7d0ff \
  --keyhl-color=68e054ff \
  --bshl-color=ffb4abff \
  --clock --indicator \
  --time-str="%H:%M:%S" --date-str="%A, %Y-%m-%d"
