# Debian packages this rice expects

For Debian 13 (trixie). This list is what `installer/preseed.cfg`'s `pkgsel/include`
and `installer/late.sh` install before applying this repo with `chezmoi`.

## Desktop/WM
```
xorg i3-wm i3lock i3status
polybar picom dunst rofi feh imagemagick
sddm qml6-module-qtmultimedia qml6-module-qtquick-virtualkeyboard qt6-virtualkeyboard-plugin
xss-lock x11-xserver-utils xdg-utils xsettingsd
lxpolkit gammastep blueman xdg-desktop-portal-gtk libnotify-bin
nautilus loupe gnome-text-editor gnome-calculator
network-manager network-manager-gnome
pulseaudio pulseaudio-utils pavucontrol playerctl
brightnessctl maim xclip
```
Display manager: SDDM with the ml4w theme (as on the Arch rice; the live ISO
ships it in `/usr/share/sddm/themes/ml4w`, selected by
`/etc/sddm.conf.d/10-xcloud.conf`). SDDM runs Debian's Xsession for the i3
session, which sources `~/.xsessionrc` (session environment).

## Quickshell shell (bar, power menu, launcher, calendar, OSD, sidebar)
`quickshell` itself is not in Debian: it is the xcloud-built
`quickshell_0.3.1-1~xcloud+deb13u1_amd64.deb` (X11 + i3 IPC, no Wayland/Hyprland
modules). Everything below is in trixie:
```
qml6-module-qtquick qml6-module-qtquick-layouts qml6-module-qtquick-controls
qml6-module-qtquick-templates qml6-module-qtquick-effects qml6-module-qtquick-window
qml6-module-qtquick-shapes qml6-module-qtqml-workerscript qt6-svg-plugins
libgl1-mesa-dri
upower power-profiles-daemon
```
`libgl1-mesa-dri`: the shell's icon colorizing and shadows are `MultiEffect`
shaders, which need a GL scene graph (under `QT_QUICK_BACKEND=software` they
simply don't draw). `upower`/`power-profiles-daemon` back the battery and
power-profile modules. Also used, already listed elsewhere here: `dunst`
(`dunstctl`), `pulseaudio-utils` (`pactl` -- volume works with PulseAudio or
pipewire-pulse), `pavucontrol`, `brightnessctl`, `xss-lock`, `x11-xserver-utils`
(`xset`), `fonts-noto-color-emoji`, `qt6ct`, `rofi`, `kitty`. Icons: kora
(see "Not packaged" below), `papirus-icon-theme` as the fallback.
**Fira Sans** (the UI font) is not packaged in trixie -- the live ISO installs
it system-wide; elsewhere `run_once_install-fira-sans.sh` installs it per user
(pinned google/fonts commit, sha256-checked; a no-op when the font exists).

## Terminal / shell / editors (already-reused app configs)
```
kitty tmux fish zsh neovim vim git curl ca-certificates sudo
fzf zoxide direnv atuin eza fastfetch
```

## Fonts / theming
```
fonts-jetbrains-mono fonts-font-awesome fonts-noto-color-emoji
papirus-icon-theme bibata-cursor-theme
gtk2-engines-murrine gnome-themes-extra qt6ct kde-style-breeze
```
`kde-style-breeze`: the Qt widget style qt6ct.conf selects (`style=Breeze`), as
on the Hyprland rice; qt6ct's custom palette is matugen's
`~/.config/qt6ct/colors/matugen.conf`. `~/.xsessionrc` sets
`QT_QPA_PLATFORMTHEME=qt6ct`, the cursor and `QS_ICON_THEME`.

## Wallpaper / theming (matugen)
The palette is generated from the wallpaper, like on the Hyprland rice:
`~/.config/xcloud/scripts/xcloud-wallpaper` sets it with `feh` and runs
`matugen image <img> -t scheme-content -m dark --prefer=saturation`
(`~/.config/matugen/config.toml`: kitty, tmux, btop, rofi, gtk, qt6ct, i3,
i3lock, dunst, polybar, oh-my-posh and the Quickshell/nvim `colors.json`), then
makes the blurred/square variants with ImageMagick (`magick`, so ImageMagick 7
-- trixie's `imagemagick` is 7.1). The rendered outputs for the default
wallpaper are committed, so everything is themed before the first run.
Not in trixie, installed by the live ISO:
- **matugen 4.2.0** -- upstream static binary at `/usr/local/bin/matugen`
- **waypaper 2.9** -- wallpaper picker (SUPER+CTRL+W), `pipx` install exposed at
  `/usr/local/bin/waypaper`, `feh` backend
- **kora** icon theme -- in `/usr/share/icons/kora` (upstream bikass/kora)
- **forest2.jpg**, the default wallpaper -- `/usr/share/backgrounds/xcloud/`
Optional: **i3lock-color** (not packaged in Debian) -- `lock.sh` uses it for
the hyprlock-style clock when present, plain `i3lock` otherwise.

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
iptables
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
- `fastfetch`, `atuin` — both are in trixie after all (listed above).
- `oh-my-posh` — upstream static binary to `/usr/local/bin`, checksum-verified
  (live ISO: `xc0-sh/baldr` hook 0050).
- oh-my-zsh plus the custom plugins `zsh-autosuggestions`,
  `zsh-syntax-highlighting` and `fast-syntax-highlighting` — git checkouts at
  pinned commits in `~/.oh-my-zsh` (live ISO: `xc0-sh/baldr` hook 0250).
