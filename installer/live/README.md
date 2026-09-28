# xCloud Debian 13 live ISO

One generic ISO: Debian 13 (trixie) + X11 + i3 + `xcloud-gg/dotfiles` for both
`marius` (1001) and `xcloud` (1000). It boots **live**, so any PC can be checked
without touching a disk, and it **installs by copying the squashfs** (d-i with
`live-installer`), so there are no package downloads during install.

## Build (on loki, Arch)

```
sudo pacman -S --needed debootstrap debian-archive-keyring   # once
./build.sh                                                   # -> build/xcloud-live-amd64.iso
```

`build.sh` debootstraps a trixie builder chroot (`build/builder`), installs
`live-build` in it, and runs `lb build` there. `mksquashfs` is capped at
`-processors 2 -mem 1G` for loki's RAM. Inputs kept out of git:
`/opt/claude/xcloud/xcloud-agent-kit.tar.gz` (its SHA256SUMS are checked in a
hook) and `operator.pub` (marius's **public** SSH key).

## Boot menu

| Entry | What it does |
|---|---|
| Live | desktop as marius (autologin), nothing written to disk |
| Install – thor | OS on `nvme1n1`; **wipes `nvme0n1`** → Btrfs `@games`/`@data` on `/mnt/games`, `/mnt/data` |
| Install – single internal disk | OS on the only non-USB internal disk (asks if there are several); other disks untouched |

Install layout: ESP 538M, `/boot` ext4 1G, LUKS2 → LVM `xcloud_vg/root` →
Btrfs subvolumes `@ @home @log @docker @srv` (zstd:3, `@docker`/`@srv`
nodatacow), zram swap. Interactive during install, in this order:

1. hostname;
2. **"Write the changes to disks and configure LVM?"**: this names the OS disk
   and defaults to No. Nothing has been written before this screen;
3. LUKS passphrase (twice);
4. the partitioning summary, then "Write the changes to disks?".

`late.sh` then reshapes Btrfs into the subvolumes, writes fstab/crypttab and
the Debian apt sources, purges the live-system packages, and (thor entry only)
sets up the data disk.

## First boot (tty1, before the desktop)

`xcloud-firstboot` does what can't be baked into an image:

1. creates a fresh machine-id and SSH host keys;
2. sets marius's password;
3. chooses agent-kit roles from the hostname (`thor` → `platform,aios-thor`,
   anything else → `aios-debian`; you confirm or override);
4. installs the agent kit and runs its `bootstrap-host.sh`, which asks for xcloud's
   password and creates:
   - the `/opt/claude/xcloud` tree (root:xcloud 0750, one workspace per agent);
   - the `xca-*` wrappers and sudoers, and the Claude Code managed settings;
   - age/deploy/ansible keys, and `aios`.

   **Which kit.** If the ISO was built with `live/signer.pub` (the operator's git
   *signing* public key, an optional build input kept out of git), first boot shows
   its fingerprint and, on Y, runs the dotfiles repo's `bootstrap/agent-host.sh`
   (baked in by hook 0200 from the same commit as the rice, so nothing is piped
   from the network into a shell). That fetches the newest `kit-*` tag of
   `xc0-sh/xcloud-docs`, refuses it unless the tag is signed by that key and its
   checksums match, runs its `bootstrap-host.sh`, and offers to register the
   host's two deploy keys (docs read-only, state read-write) through a temporary
   `gh` device login that is removed afterwards. Without `signer.pub`, with no
   network or no `kit-*` tag yet, or if that fails and you accept the fallback,
   the kit baked into the ISO is used, as before. `/root/xcloud-firstboot.txt`
   records which one ran.

Public keys go to `/root/xcloud-firstboot.txt`. If a step fails, it drops to a
root shell and the desktop doesn't start. Re-run with `/usr/local/sbin/xcloud-firstboot`.

On each user's first login, a `systemd --user` oneshot (`xcloud-first-login`)
runs `chezmoi apply --include=scripts`, which sets up rootless Docker.

The shell tooling the zshrc expects is baked in: fzf, zoxide, direnv, atuin,
eza, fastfetch (Debian), oh-my-posh (upstream binary, hook 0050), and
oh-my-zsh with its custom plugins at pinned commits in both homes (hook 0250).

Still manual afterwards: `claude` sign-in as xcloud, and netbird enrollment
(per the agent kit README). On the operator's own workstation (not agent hosts),
marius additionally runs the repo's one-liner in operator mode:
`bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) operator`.

## Deviations and caveats

- **NVIDIA:** `nvidia-driver` is baked in (decision 2026-09-27), ahead of
  aios-thor-agent Phase 2. The image ships no DKMS signing key (scrubbed in
  hook 9900), so the NVIDIA module won't load under Secure Boot until the host
  has its own key. Either turn Secure Boot off, or after first boot run:

  ```
  sudo dkms remove nvidia-current/550.163.01 --all   # version: `dkms status`
  sudo dkms install nvidia-current/550.163.01        # new per-host key in /var/lib/dkms
  sudo mokutil --import /var/lib/dkms/mok.pub        # choose a one-time password
  sudo reboot                                        # MokManager: Enroll MOK, enter it
  ```

  Later kernel updates rebuild and sign with the same host key automatically.
- marius is in `sudo` (with a password), but not in `aios`, `docker`, or any
  runtime group (aiOS invariant 12). Docker is rootless only; the system daemon is masked.
- `bootstrap-host.sh` adds xcloud to `sudo` on Debian as well. That's the kit's
  design: NOPASSWD is granted only for the wrappers.
- In a VM with a plain VGA adapter (QEMU `-vga std`), picom's `glx` backend
  paints the whole screen black; i3 is running underneath. Real GPUs are fine.
- `nvidia-persistenced` shows as failed on machines without an NVIDIA GPU.
- Re-running `xcloud-firstboot` by hand starts from the top (asks for
  marius's password again).
- The rofi configs import `~/.config/xcloud/settings/*.rasi`, which only exist
  in the Arch/Hyprland rice.
- **SDDM autologin (live only):** live-config's `0085-sddm` writes
  `/etc/sddm.conf` with `[Autologin] User=marius` at boot, into the live overlay,
  but leaves `Session=` empty for anything but Plasma/LXQt, which sends SDDM to
  the greeter. `includes.chroot/usr/lib/live/config/0086-xcloud-sddm-session`
  runs right after it and sets `Session=i3.desktop`. The installed system is a
  copy of the squashfs, which has no `/etc/sddm.conf`, so it never autologs in
  (`/etc/sddm.conf.d/10-xcloud.conf` has no `[Autologin]`); live-config and its
  scripts don't run there (late.sh purges live-config; the 0086 file stays, inert).
- **Keyboard:** `/etc/default/keyboard` ships with `XKBLAYOUT="no"` and
  `XKBOPTIONS="grp:alt_shift_toggle"` (the Arch rice's `kb_options`; with one
  layout it does nothing). d-i copies its own file into the target, so
  `late.sh` puts the option back. Caps Lock is remapped by keyd, as on loki:
  trixie ships 2.5.0 (loki has 2.6.0), with the binary renamed to `keyd.rvaiya`.
- **waypaper** lives in a plain venv (`/opt/waypaper`), not pipx: trixie's pipx
  1.7.1 downloads an unpinned pip into its shared venv, then refused the
  `--no-deps` install.

## Look & feel

Matches the Arch desktop (loki). Everything below is pinned; downloads are
sha256-checked in the hook.

| What | Where | Version / pin | License / origin |
|---|---|---|---|
| SDDM theme `ml4w` | vendored, `includes.chroot/usr/share/sddm/themes/ml4w` (`VENDORED.txt`) | mylinuxforwork/ml4w-sddm `aa6904f` (SilentSDDM 1.4.0 fork), copied from loki | GPL-3.0-or-later |
| Wallpaper `forest2.jpg` | vendored, `/usr/share/backgrounds/xcloud/` and as the SDDM theme's `ml4w.jpg`/`default.jpg` | 3840x2160, md5 `8c73ee9b51a0b3ef58dbdbed547a6a52` | ML4W wallpaper repo (github.com/mylinuxforwork/wallpaper, `/opt/git/wallpaper` on loki; repo license GPL-2.0); original author unknown |
| Wallpaper cache (`~/.cache/xcloud/hyprland-dotfiles/*`) | hook 0270, for marius, xcloud and `/etc/skel` | rendered from forest2.jpg at build time | — |
| Fira Sans (18 styles + `OFL.txt`) | vendored, `/usr/share/fonts/truetype/fira-sans` | from the Arch rice's `setup/fonts/Fira_Sans` | SIL OFL 1.1 |
| JetBrainsMono Nerd Font | hook 0055, `/usr/share/fonts/truetype/jetbrains-mono-nerd` | nerd-fonts v3.5.1 (as Arch), `JetBrainsMonoNerdFont-*` only | SIL OFL 1.1 |
| matugen | hook 0055, `/usr/local/bin/matugen` | v4.2.0 x86_64 release binary | GPL-2.0 |
| kora + kora-pgrey icons | hook 0055, `/usr/share/icons/` | bikass/kora `7a75842` (master when loki installed it, one commit past v2.0.6) | GPL-3.0 |
| waypaper | hook 0065, `/opt/waypaper`, `/usr/local/bin/waypaper` | 2.9 wheel from PyPI (as Arch) | GPL-3.0 |
| Cursor | `x-cursor-theme` alternative → Bibata-Modern-Ice (Debian package); SDDM `CursorTheme` | — | — |

Settings files: `etc/sddm.conf.d/10-xcloud.conf` (theme, virtual keyboard,
Bibata cursor, `Numlock=none`, X11), `etc/X11/xorg.conf.d/40-libinput-touchpad.conf`
(natural scrolling, tap to click), `etc/default/keyboard`, `etc/keyd/default.conf`
(copied from loki unchanged).

## Testing in QEMU (on loki)

What was verified on 2026-09-27, and how: `build/vm/` (gitignored) holds a
sparse raw disk; boot headless with `-display none -monitor unix:…` and drive it
with `sendkey`/`screendump`. The live keymap is Norwegian, and keys sent faster
than QEMU's 100 ms hold time overlap (seen as spurious resets). Use
`-device nvme` disks; the first one attached becomes `nvme0n1`.
