#!/bin/sh
# move-pane-to-window.sh N PANE_ID -- tmux analog of SUPER+SHIFT+N "Move window
# to workspace N" (bound on prefix + Shift+digit in ~/.tmux.conf): the pane joins
# window N if it exists, otherwise becomes window N; focus follows the pane.
n=$1 pane=$2
[ -n "$n" ] && [ -n "$pane" ] || exit 1

sess=$(tmux display-message -p -t "$pane" '#{session_id}')
[ "$(tmux display-message -p -t "$pane" '#{window_index}')" = "$n" ] && exit 0

if tmux list-windows -t "$sess" -F '#{window_index}' | grep -qx "$n"; then
    tmux join-pane -s "$pane" -t "$sess:$n"
elif [ "$(tmux display-message -p -t "$pane" '#{window_panes}')" -eq 1 ]; then
    # break-pane refuses a window's only pane -- move the whole window instead
    tmux move-window -s "$pane" -t "$sess:$n"
else
    tmux break-pane -s "$pane" -t "$sess:$n"
fi
# by pane id, not index: renumber-windows may have shifted the indexes
tmux select-window -t "$pane" \; select-pane -t "$pane"
