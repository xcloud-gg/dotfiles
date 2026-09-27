#!/bin/sh
# Zen Browser isn't in Debian's repos. Official docs (docs.zen-browser.app)
# recommend Flatpak/Flathub as the primary Linux install method, but that pulls
# in flatpak+flathub as a new system dependency just for one app; the official
# tarball installer avoids that and is still first-party (zen-browser/desktop).
set -eu

if [ -x "$HOME/.local/bin/zen" ]; then
    echo "zen-browser already installed, skipping"
    exit 0
fi

curl -fsSL https://github.com/zen-browser/updates-server/raw/refs/heads/main/install.sh | bash
# ^ deliberately `bash`, not `sh` — the upstream script uses bash-only syntax
# ([[ ]]) and Debian's /bin/sh is dash, which would fail on it.
