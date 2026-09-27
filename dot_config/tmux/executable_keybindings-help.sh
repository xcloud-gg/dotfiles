#!/usr/bin/env bash
# Curated keybind reference + the mirroring logic behind this config, shown
# via `prefix C-k` (mirrors the desktop's SUPER+CTRL+K "Show keybindings",
# ~/.config/i3/config). The system-key table is the mapping itself; the
# lists after it are pulled live from tmux (list-keys -N), so they can't
# drift out of sync with ~/.tmux.conf's actual binds.

bold=$(tput bold 2>/dev/null); reset=$(tput sgr0 2>/dev/null)

# `list-keys -T <table> -N` emits one "<key>  <note>" line per bind that has
# a note (ours from -N, plus tmux's own noted defaults). Some tmux versions
# (3.7) prepend the prefix key as an extra column and 3.5 doesn't; `-P ''`
# blanks that column on both, leaving only optional leading spaces to strip.
extract() {
    tmux list-keys -T "$1" -N -P '' | sed -E 's/^ *([^ ]+) +/\1\t/'
}

{
cat <<TEXT
${bold}THE LOGIC${reset}
tmux's ${bold}prefix${reset} (Alt+', or CapsLock-hold+A; Ctrl+a as fallback) plays
the role of the desktop's ${bold}SUPER${reset} key. A desktop window is a tmux
${bold}pane${reset}; a desktop workspace is a tmux ${bold}window${reset}. So wherever SUPER+key
does something to windows/workspaces, prefix + the same key does the same
thing to panes/windows. Letters use Shift (prefix Shift+F = SUPER+F) because
the lowercase prefix keys are tmux's own defaults (d detach, c new window,
[ copy mode, z zoom ...) and stay where your fingers expect them.

${bold}SYSTEM KEY            TMUX (prefix, then ...)   ACTION${reset}
SUPER+Return          Enter                     new pane (auto split, cwd)
SUPER+Q               Shift+Q                   kill pane (y/n)
SUPER+Shift+Q         Shift+X                   kill window (y/n)
SUPER+arrows          arrows (or h j k l)       focus pane
SUPER+Shift+arrows    Shift+arrows (repeat)     resize pane
SUPER+Alt+arrows      Alt+arrows (repeat)       swap pane in that direction
SUPER+1..9,0          1..9,0                    go to window 1..9,0
SUPER+Shift+1..9,0    Shift+1..9,0              move pane to window N
                      (! " # ¤ % & / ( ) =)
SUPER+F / SUPER+M     Shift+F / Shift+M         zoom pane (fullscreen)
SUPER+J               Shift+J                   toggle split: side-by-side/stacked
SUPER+K               Shift+K                   rotate panes (swapsplit)
SUPER+G               Shift+G                   pick a pane of this window (tabs)
SUPER+S               Shift+S                   scratchpad popup (toggle)
SUPER+Tab             Tab                       window/pane overview
SUPER+V               Shift+V / Ctrl+V          copy mode / buffer history
SUPER+Ctrl+R          Ctrl+R (or r)             reload config
SUPER+Ctrl+K          Ctrl+K                    this help

${bold}CAPSLOCK LAYER${reset} (hold CapsLock; no prefix needed)
CapsLock+A            the prefix itself
CapsLock+C            enter copy mode / finish the selection into a tmux buffer
CapsLock+V            paste the X clipboard (no X, e.g. over SSH: newest tmux buffer)
CapsLock+X            push the newest tmux buffer to the X clipboard (xclip)
Every copy is also sent to the terminal's clipboard via OSC 52, so it
reaches your local clipboard over SSH too. In copy mode: v selects, y copies.

tmux-only extras (nothing to mirror): s sessions, e sync panes, g lazygit,
b btop, T pane titles, N / Ctrl+N nested marker, | \\ - splits.

${bold}PREFIX-TABLE BINDS${reset} (press prefix, then the key)
TEXT
extract prefix | column -t -s "$(printf '\t')"

cat <<TEXT

${bold}UNPREFIXED BINDS${reset} (no prefix needed)
TEXT
extract root | column -t -s "$(printf '\t')"
} | less -R
