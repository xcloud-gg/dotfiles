#!/bin/sh
# Docker packages are installed system-wide by installer/late.sh, but rootless
# mode itself is set up here instead of there, because it needs a live
# `systemctl --user` session — not available inside the installer's chroot.
#
# Deliberately rootless, not the system-wide daemon + `docker` group: adding
# the desktop user to the `docker` group is equivalent to root (the daemon
# socket is root-owned), and aiOS invariant 12 (aios-thor-agent-prompt.md)
# requires the desktop user stay out of every container-runtime group. If you
# didn't come here from thor/that install, this still applies — it's a
# reasonable default even without the aiOS constraint.
set -eu

if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    echo "docker-ce-rootless-extras not installed — nothing to do yet"
    echo "(this runs after installer/late.sh's Docker package install; if"
    echo "you're not on a machine that ran that installer, install Docker"
    echo "first, then re-run: chezmoi apply)"
    exit 0
fi

if [ -z "${XDG_RUNTIME_DIR:-}" ] || ! systemctl --user status >/dev/null 2>&1; then
    echo "No live user session (systemctl --user unavailable) — can't set up"
    echo "rootless Docker from here (e.g. running non-interactively at first"
    echo "boot). Log in normally, then run: chezmoi apply"
    exit 0
fi

if systemctl --user is-active --quiet docker.service 2>/dev/null; then
    echo "rootless docker already running, skipping"
    exit 0
fi

dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker.service
loginctl enable-linger "$(whoami)" 2>/dev/null || true

echo "rootless Docker set up. DOCKER_HOST is exported by"
echo "dockerd-rootless-setuptool.sh's own shell profile snippet; open a new"
echo "shell (or re-source your rc file) before running docker commands."
