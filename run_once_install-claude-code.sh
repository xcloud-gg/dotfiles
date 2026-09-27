#!/bin/sh
# Native installer — the officially recommended method (auto-updates in the
# background; matches how the aiOS agent-kit's own bootstrap-host.sh installs
# Claude Code for the `xcloud` account, so this stays consistent fleet-wide).
set -eu

if [ -x "$HOME/.local/bin/claude" ]; then
    echo "claude already installed, skipping"
    exit 0
fi

curl -fsSL https://claude.ai/install.sh | bash
# ^ `bash`, not `sh` — same reason as the zen-browser script: upstream uses
# bash-only syntax and Debian's /bin/sh is dash.
