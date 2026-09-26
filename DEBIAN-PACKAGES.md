# Debian packages this rice expects

For Debian 13 (trixie). This list is what the Baldr/thor installer's preseed
`late_command` installs before applying this repo with `chezmoi`.

## Desktop/WM
```
xorg i3-wm i3lock i3status
polybar picom dunst rofi nitrogen feh
lightdm lightdm-gtk-greeter
xss-lock numlockx x11-xserver-utils
network-manager network-manager-gnome
pulseaudio pulseaudio-utils pavucontrol playerctl
brightnessctl maim xclip
```

## Terminal / shell / editors (already-reused app configs)
```
kitty tmux fish zsh neovim vim git
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
chezmoi
firefox-esr chromium
```

## thor-specific (NVIDIA RTX 3080 — not part of the portable/generic set)
```
nvidia-driver firmware-misc-nonfree
nvidia-cuda-dev nvidia-container-toolkit
```

## Not packaged for Debian — install separately
- `fastfetch` — not in Debian's repos as of trixie; grab the `.deb` release
  from https://github.com/fastfetch-cli/fastfetch/releases in `late_command`
  or a first-boot script.
- `atuin`, `oh-my-posh` — install via their own installer scripts (already
  assumed by `dot_config/atuin` and `dot_config/ohmyposh` if reused as-is).
