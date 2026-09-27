# Debian packages this rice expects

For Debian 13 (trixie). This list is what `installer/preseed.cfg`'s `pkgsel/include`
and `installer/late.sh` install before applying this repo with `chezmoi`.

## Desktop/WM
```
xorg i3-wm i3lock i3status
polybar picom dunst rofi nitrogen feh
lightdm lightdm-gtk-greeter
xss-lock numlockx x11-xserver-utils xdg-utils
network-manager network-manager-gnome
pulseaudio pulseaudio-utils pavucontrol playerctl
brightnessctl maim xclip
```

## Terminal / shell / editors (already-reused app configs)
```
kitty tmux fish zsh neovim vim git curl ca-certificates sudo
```

## Fonts / theming
```
fonts-jetbrains-mono fonts-font-awesome fonts-noto-color-emoji
papirus-icon-theme bibata-cursor-theme
gtk2-engines-murrine gnome-themes-extra qt6ct
```

## Portability / driver set (from aios-portable-agent-prompt.md §4/§6 —
## generic "borrowed hardware" support; also applies to any Debian target,
## including thor)
```
firmware-linux firmware-misc-nonfree
network-manager autorandr zram-tools
mesa-utils libgl1-mesa-dri xserver-xorg-video-all
unattended-upgrades
firefox-esr chromium
```

## chezmoi — NOT in trixie's archive
`chezmoi` is only packaged in Debian **sid**, not trixie, so `apt install
chezmoi` fails on Debian 13 (found building the live ISO, 2026-09-27 — it was
listed above as an apt package, and the netinst preseed's `pkgsel/include`
carried the same mistake). Install the official upstream `.deb`, checksum-verified:
```
v=2.72.2
base=https://github.com/twpayne/chezmoi/releases/download/v$v
curl -fsSLO "$base/chezmoi_${v}_linux_amd64.deb"
curl -fsSL "$base/chezmoi_${v}_checksums.txt" | grep " chezmoi_${v}_linux_amd64.deb\$" | sha256sum -c -
sudo apt install ./chezmoi_${v}_linux_amd64.deb
```
The live ISO does exactly this in its build hook `0050-xcloud-thirdparty`.

## Filesystem / encryption
```
btrfs-progs cryptsetup tpm2-tools
```
`lvm2` isn't listed explicitly — the Debian installer pulls it in automatically
for a guided-LVM install. See `installer/preseed.cfg` and `installer/late.sh`
for the actual LUKS2 → LVM → Btrfs (subvolumes `@ @home @log @docker @srv`)
layout and why it's shaped that way.

## Docker (rootless — see `run_once_setup-docker-rootless.sh`)
```
docker-ce docker-ce-cli containerd.io docker-buildx-plugin
docker-compose-plugin docker-ce-rootless-extras uidmap dbus-user-session slirp4netns
```
Installed from Docker's own apt repo (not Debian's), added by `installer/late.sh`.
Deliberately **not** paired with `usermod -aG docker <user>` — see the script's
comments for why (aiOS invariant 12, and it's a reasonable default regardless).

## thor-specific (NVIDIA RTX 3080 — not part of the portable/generic set)
```
nvidia-driver firmware-misc-nonfree
nvidia-cuda-dev nvidia-container-toolkit
```

## Not packaged for Debian — installed via `chezmoi` `run_once_` scripts instead
- **`zen-browser`** (default browser — `dot_config/mimeapps.list`,
  `BROWSER=zen` in the shell rc files, `$mod+b` in i3) — official tarball
  installer (`run_once_install-zen-browser.sh`), not Flatpak, to avoid adding
  flatpak+flathub as a dependency for one app.
- **`claude-code`** — official native installer
  (`run_once_install-claude-code.sh`), same method `bootstrap-host.sh` uses for
  the `xcloud` account, kept consistent fleet-wide. Auto-updates in the
  background.
- `fastfetch` — not in Debian's repos as of trixie; the shell rc files already
  guard every `fastfetch` call with `command -v fastfetch` so its absence is
  silent rather than a `command not found` error (relevant for a minimal/CLI-
  guest session that hasn't installed it). Grab the `.deb` release from
  https://github.com/fastfetch-cli/fastfetch/releases if you want it.
- `atuin`, `oh-my-posh` — install via their own installer scripts (already
  assumed by `dot_config/atuin` and `dot_config/ohmyposh` if reused as-is).
