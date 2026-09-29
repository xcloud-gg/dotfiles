# installer/

**`live/` moved to its own repo: https://github.com/xc0-sh/baldr** — that's now
the canonical home for the live/installer ISO project (live-build config,
firstboot, "Install – thor" d-i entries, SDDM/Quickshell). `live/` here is just
a pointer now.

The rest of this directory is the Debian preseed that turns a bare disk into this rice, running on Ventoy's
`auto_install` plugin against the **stock, unmodified** Debian 13 netinst ISO
(deliberately not a repacked ISO — see the project history for why).

- **`preseed.cfg`** — the answer file. Keyboard, timezone, account, package
  list, and the LUKS2 → LVM → Btrfs partitioning scheme. Its `late_command`
  fetches `late.sh` from this repo (pinned to a commit, not `main`, so a later
  push here can't change what an in-progress install runs) and executes it.
- **`late.sh`** — everything too complex for a single preseed line: reshapes
  the single Btrfs volume partman creates into subvolumes (`@ @home @log
  @docker @srv`), tunes dm-crypt performance flags, installs Docker (rootless-
  capable packages only), and applies this repo with `chezmoi`.
- **`ventoy.json`** — goes on the Ventoy stick at `ventoy/ventoy.json`, next to
  a copy of `preseed.cfg` at `ventoy/debian_preseed.cfg`. Wires Ventoy's
  `auto_install` plugin to inject the preseed at boot without touching the ISO.

**Not yet boot-tested** — test in a VM (or on spare hardware) before pointing
this at anything that matters. The Btrfs reshape in `late.sh` is the highest-risk
part: it unmounts and remounts the target mid-install and rewrites `/etc/fstab`
and GRUB's config from scratch.

## What it does NOT do

Provision the actual aiOS platform. This gets a Debian/X11/i3 desktop with
drivers, default software, and this repo's dotfiles applied for the desktop
user — nothing more. aiOS itself is built afterward by a separate Claude Code
agent (`aios-thor-agent`/`aios-debian-agent`/`aios-portable-agent`, run via
`bootstrap-host.sh`), which has its own explicit boundary against touching the
desktop user's home, dotfiles, or window manager.
