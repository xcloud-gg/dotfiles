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

Install layout (unchanged from the netinst preseed): ESP 538M, `/boot` ext4 1G,
LUKS2 → LVM `xcloud_vg/root` → Btrfs subvolumes `@ @home @log @docker @srv`
(zstd:3, `@docker`/`@srv` nodatacow), zram swap. Interactive during install:
LUKS passphrase, hostname, and one "write changes to disk" confirmation.

## First boot (tty1, before the desktop)

`xcloud-firstboot` does what can't be baked into an image:

1. creates a fresh machine-id and SSH host keys;
2. sets marius's password;
3. chooses agent-kit roles from the hostname (`thor` → `platform,aios-thor`,
   anything else → `aios-debian`; you confirm or override);
4. runs `bootstrap-host.sh`, which asks for xcloud's password and creates:
   - the `/opt/claude/xcloud` tree (root:xcloud 0750, one workspace per agent);
   - the `xca-*` wrappers and sudoers, and the Claude Code managed settings;
   - age/deploy/ansible keys, and `aios`.

Public keys go to `/root/xcloud-firstboot.txt`. If a step fails, it drops to a
root shell and the desktop doesn't start. Re-run with `/usr/local/sbin/xcloud-firstboot`.

On each user's first login, a `systemd --user` oneshot (`xcloud-first-login`)
runs `chezmoi apply --include=scripts`, which sets up rootless Docker.

Still manual afterwards: `claude` sign-in as xcloud, and netbird enrollment
(per the agent kit README).

## Deviations and caveats

- **NVIDIA:** `nvidia-driver` is baked in (decision 2026-09-27), ahead of
  aios-thor-agent Phase 2. The DKMS module is unsigned: on thor, either turn
  Secure Boot off or enroll a MOK.
- marius is in `sudo` (with a password), but not in `aios`, `docker`, or any
  runtime group (aiOS invariant 12). Docker is rootless only; the system daemon is masked.
- `bootstrap-host.sh` adds xcloud to `sudo` on Debian as well. That's the kit's
  design: NOPASSWD is granted only for the wrappers.
