#!/usr/bin/env bash

# Refreshes the tmux SERVER's global DISPLAY/XAUTHORITY/XDG_RUNTIME_DIR/
# DBUS_SESSION_BUS_ADDRESS from systemd --user's own (live) activation
# environment. Run from client-attached/pane-focus-in hooks (see .tmux.conf).
#
# Why this exists: every clipboard/link-opening path out of tmux (xclip,
# xdg-open) runs as a tmux *job* (run-shell, copy-pipe, tmux-thumbs'
# --command), and jobs inherit the server's global environment (plus the
# session's). A server that outlives an X session restart (e.g. tmux kept
# alive by tmux-continuum) otherwise keeps a stale DISPLAY/XAUTHORITY cookie
# path forever, and xclip starts failing with zero visible signal (its
# errors are suppressed by design -- see the binds in .tmux.conf).
#
# systemd --user's environment is re-pushed on every X login by Debian's
# /etc/X11/Xsession.d/20dbus_xdg-runtime (dbus-update-activation-environment
# --systemd DISPLAY XAUTHORITY ...), which SDDM's Xsession runs -- so it is
# always current. Per-client values still win: tmux's default
# update-environment copies DISPLAY/XAUTHORITY from each attaching client
# into the session, and unsets them for an SSH attach without X forwarding.

env_snapshot=$(systemctl --user show-environment 2>/dev/null)
for var in DISPLAY XAUTHORITY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS; do
    value=$(sed -n "s/^${var}=//p" <<< "$env_snapshot")
    if [ -n "$value" ]; then
        tmux set-environment -g "$var" "$value"
    fi
done

# Always exit 0: no live systemd --user session (e.g. a TTY/SSH-only login
# with no X session at all) is an expected, silent no-op case, not a hook
# failure -- otherwise the last loop iteration's `[ -n ... ]` test becomes
# the exit status and tmux logs "'script' returned 1" on every attach/focus.
exit 0
