# xcloud-gg/dotfiles

The Debian / X11 / i3 rice for `fenrir` (the portable live ISO), `baldr` (the operator laptop) and `thor` — the portable-hardware
counterpart to the Hyprland/Wayland rice at
[`xc0sh/dotfiles`](https://github.com/xc0sh/dotfiles), whose theme (colors, fonts,
cursor) this repo matches. Managed with [chezmoi](https://chezmoi.io): every
`dot_`-prefixed path maps to a dotfile in `$HOME` (`dot_config/i3/config` →
`~/.config/i3/config`).

Colours: generated from the wallpaper by matugen, exactly as on the Hyprland rice
(`dot_config/matugen/`, run by `~/.config/xcloud/scripts/xcloud-wallpaper` and
waypaper); the committed outputs are the palette of the default wallpaper
`forest2.jpg` (background `#101418` · foreground `#e0e2e8` · primary `#9cd0ff`) ·
font `JetBrainsMono Nerd Font` (terminal) / `Fira Sans` (UI) · cursor
`Bibata-Modern-Ice` · icons `kora`.

## What's new here (not in `xc0sh/dotfiles`)

Window-manager chrome, since Hyprland/Wayland has no i3/X11 equivalent:
- `dot_config/i3/` — window manager config (colours `include`d from the
  matugen-generated `colors.conf`) + `scripts/lock.sh` (replaces `hyprlock`:
  blurred wallpaper, i3lock-color when installed), `scripts/idle.sh`/`dim.sh`
  (xss-lock + `xset`, replaces `hypridle` with the same 8/10/11 min timings),
  `scripts/nightlight.sh` (gammastep, replaces `hyprsunset`) and
  `scripts/rofi-powermenu.sh` (replaces `wlogout`)
- `dot_config/xcloud/scripts/xcloud-wallpaper` — X11 port (feh instead of awww),
  `dot_config/waypaper/` (feh backend) and `dot_config/matugen/` (X11 outputs:
  i3, i3lock, dunst, polybar instead of hyprland/waybar/swaync/wlogout)
- `dot_xsessionrc` — session environment (qt6ct, cursor, Quickshell icon theme)
- `dot_config/quickshell/` — X11/i3 port of the Hyprland rice's Quickshell shell
  (status bar, power menu, launcher, calendar, OSD, reduced sidebar), started by
  `i3/scripts/quickshell.sh`; see the header of `shell.qml` for how it maps onto
  i3. Not ported: dock, wallpaper picker, welcome app, workspace overview.
  Support files it expects live in `dot_config/xcloud/` (`colors/colors.json`
  palette from matugen, `settings/`, `scripts/xcloud-power` etc.)
- `dot_config/polybar/` — former status bar (replaces `waybar`); still shipped but
  no longer started by i3 — Quickshell replaced it
- `dot_config/picom/` — compositor for blur/shadow/opacity (Hyprland does this
  natively)
- `dot_config/dunst/` — notifications (replaces `swaync`)
- `dot_config/rofi/config-i3.rasi`, `config-i3-powermenu.rasi` — new, self-contained
  rofi configs. The launcher (SUPER+SPACE) uses the original `config.rasi`, as on
  Hyprland, with its `~/.config/xcloud/settings/rofi-*.rasi` snippets shipped
  here and the wallpaper panel from xcloud-wallpaper's `current_wallpaper.rasi`
  (`config-i3.rasi` until that exists)
- `dot_xinitrc` — for `startx`/a display manager's `Xsession` fallback
- `dot_config/mimeapps.list` — default-app associations (see "Default apps" below)

Everything else (`kitty`, `rofi`'s base config/colors, `tmux`, `nvim`, `vim`, `fish`,
`zsh`/`bash`, `git`, `btop`, `fastfetch`, `gtk-*`, `qt6ct`, `xsettingsd`, `atuin`,
`ohmyposh`, `.Xresources`) is carried over as-is from `xc0sh/dotfiles` — it's already
window-manager-agnostic.

`dot_zshrc`'s/`dot_config/bashrc`'s `finder()` function (the `ff` command) calls
`~/.config/xcloud/bin/xcloud-finder`, part of the Hyprland side's `xcloud` app and
not included here — it now fails with a clear message instead of a bare
`command not found` if that helper is missing. Same treatment for every
`fastfetch` call (not packaged for Debian — see `DEBIAN-PACKAGES.md`), so a
minimal/CLI-guest session that never installed it stays quiet instead of erroring
on every new shell.

## Default apps

- **Browser: Zen** (`run_once_install-zen-browser.sh`, official tarball
  installer — not Flatpak, to avoid a new system dependency for one app).
  Set as default via `dot_config/mimeapps.list` (declarative — no runtime
  `xdg-settings` call needed) and `BROWSER=zen` in every shell's rc; `$mod+b`
  in i3 launches it.
- **Claude Code** (`run_once_install-claude-code.sh`, official native
  installer — the same method `bootstrap-host.sh` uses for the `xcloud`
  account, kept consistent fleet-wide; auto-updates in the background).
- **Docker, rootless** (`run_once_setup-docker-rootless.sh`). Packages come
  from `installer/late.sh` (Docker's own apt repo); this script runs the
  actual `dockerd-rootless-setuptool.sh install` at first login, since that
  needs a live user session the installer's chroot doesn't have. Deliberately
  *not* the system-wide daemon + `docker` group — see the script's comments.

## One-line install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) [MODE] [--ref REF] [OPTIONS]
```

| Mode | For | What it does |
|---|---|---|
| `dotfiles` (default) | any Debian 13 / Arch desktop user | installs chezmoi, clones this repo, `chezmoi init --apply` (re-run to update) |
| `operator` | the operator workstation — loki now, thor once built | gh + Claude Code; `~/xcloud/xcloud-docs` and `~/xcloud/xcloud-state`, kept current by `xcloud-sync` (docs `main` only across commits signed by your pinned key); `xcloud-approve` on `PATH`; the operator Claude workspace `~/xcloud/operator` whose SessionStart hook loads the build state (revisions, proposals waiting for your signature, every agent's phase, hand-offs to you). Never applies the i3 rice, never touches private keys |
| `agent-host` | an agent host **not** installed from the live ISO | fetches the kit from a signed `kit-*` tag of `xc0-sh/xcloud-docs`, verifies it against the signer fingerprint you type, runs `bootstrap-host.sh`, optionally registers the host's deploy keys; hosts installed from the live ISO ([`xc0-sh/fenrir`](https://github.com/xc0-sh/fenrir)) get this at first boot instead |

Everything runs from `main()` at the end of each script, so a truncated download runs nothing. For anything
that matters pin a commit: `…/dotfiles/<commit>/install.sh` plus `--ref <commit>`. `install.sh`, `bootstrap/`
and the installers are in `.chezmoiignore`. Proposed changes to `xcloud-docs` arrive unsigned on
`proposals/<topic>` branches; only you make them real, with `xcloud-approve <sha>` (signed with your key).

## Package list / installer

See `DEBIAN-PACKAGES.md` for the apt package set, and `installer/` for the actual
Debian preseed (`preseed.cfg`) and post-install script (`late.sh`) that provision
Debian 13 + X11 + i3 + LUKS2/Btrfs before applying this repo with `chezmoi`.
**`installer/late.sh`'s Btrfs subvolume reshape is not yet boot-tested** — test
in a VM before using this on real hardware.

## Status

Initial draft, authored 2026-09-27 to seed this repo (per aiOS Portable Spec v0.2
OD-P4) — not yet applied/tested on real hardware. The Portable spec's own design keeps
automated build agents from authoring the operator's dotfiles content going forward;
this first pass exists because the operator asked for it directly, not as a
precedent for agents editing it later. Review before relying on it, and expect to
iterate once it's actually running.
