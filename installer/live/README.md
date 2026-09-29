# Moved — this is now `xc0-sh/baldr`

The Debian 13 + X11 + i3 live/installer ISO (live-build config, firstboot,
"Install – thor" / "Install – single internal disk" d-i entries, SDDM/Quickshell
look & feel) moved to its own repo:

**https://github.com/xc0-sh/baldr**

That repo is now the canonical source. Build it there (`build.sh` -> `build/xcloud-live-amd64.iso`);
it still applies this repo's dotfiles (`xcloud-gg/dotfiles`) to `marius` and `xcloud` at build/firstboot
time — the two repos remain linked, just no longer nested.

This directory is kept only as a pointer for anyone who lands here from an old
link or clone. Do not add new files here.
