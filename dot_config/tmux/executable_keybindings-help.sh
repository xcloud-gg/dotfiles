#!/usr/bin/env bash
# Curated keybind reference + the mirroring logic behind this config, shown
# via `prefix C-k` (mirrors Hyprland's own SUPER+CTRL+K "Show keybindings",
# see hypr/.config/hypr/conf/keybindings/default.lua and
# hypr/.config/hypr/scripts/keybindings.sh). Pulls the live prefix/root
# tables straight from tmux itself (list-keys -N) rather than hand-
# duplicating key/description pairs, so this can't drift out of sync with
# .tmux.conf's actual binds the way a hardcoded list would.

bold=$(tput bold); reset=$(tput sgr0)

# `list-keys -T <table> -N` (tmux 3.7c) emits one pretty-printed
# "<prefix> <key>  <note>" line per bind that HAS a -N note -- everything
# else (mouse binds, tmux's own defaults) is silently skipped, so no
# filtering is needed beyond that. The leading column is always just the
# configured prefix key (shown even for root-table's unprefixed binds --
# a tmux formatting quirk, not something to read as "needs prefix") and is
# discarded here; only the key and note are kept, in the file's own
# definition order (already grouped by category via .tmux.conf's section
# comments).
extract() {
    tmux list-keys -T "$1" -N | sed -E 's/^[^ ]+ +([^ ]+) +/\1\t/'
}

{
cat <<EOF
${bold}THE LOGIC${reset}
This config mirrors loki's Hyprland keybind scheme: tmux's ${bold}prefix${reset}
(Alt+', or CapsLock-hold+A) stands in for Hyprland's ${bold}SUPER${reset} key,
since terminals can't reliably capture Super combos. Wherever a Hyprland
bind exists, the prefix-table key below is the same physical key Hyprland
uses after SUPER (e.g. SUPER+arrows moves focus in Hyprland -> prefix+arrows
moves focus between panes here).

Deliberate exceptions to that mirror:
  - CapsLock-hold+C/V/X (clipboard) work with ${bold}no prefix at all${reset} --
    always-on, since clipboard needs to work instantly, not after a chord.
  - sesh/lazygit/btop/sync-panes/pane-titles/nested-marker are tmux-only
    concepts with nothing to mirror in Hyprland.
  - Ctrl-h/j/k/l pass through to Neovim splits when the active pane IS
    Neovim, and only fall back to pane-focus otherwise.
  - Copy mode (prefix+V or CapsLock+C): once inside, 'v' starts a
    selection and 'y' copies it to tmux's own buffer (vi-style, not
    listed below -- CapsLock+X separately pushes that buffer to the
    system clipboard on demand).

${bold}PREFIX-TABLE BINDS${reset} (press prefix, then the key)
EOF
extract prefix | column -t -s "$(printf '\t')"

cat <<EOF

${bold}UNPREFIXED BINDS${reset} (no prefix needed)
EOF
extract root | column -t -s "$(printf '\t')"
} | less -R
