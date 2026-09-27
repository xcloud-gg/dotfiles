#!/bin/sh
# Fira Sans (the rice's UI font -- Quickshell's Theme.fontFamily is
# "Fira Sans Semibold", dunst/i3 use "Fira Sans") isn't packaged in Debian 13
# (only fonts-firacode, the monospace sibling). The xcloud live ISO installs
# it system-wide, so this is a no-op there; elsewhere install the upstream
# TTFs from google/fonts at a pinned commit, checksum-verified, into
# ~/.local/share/fonts.
set -eu

dest="$HOME/.local/share/fonts/FiraSans"
commit=e345593da2a4d596212542edbd28f2ed08fe6cbe
base="https://raw.githubusercontent.com/google/fonts/$commit/ofl/firasans"

if [ -f "$dest/FiraSans-SemiBold.ttf" ] || fc-list 'Fira Sans:style=SemiBold' family 2>/dev/null | grep -q .; then
    echo "Fira Sans already installed, skipping"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/SHA256SUMS" <<'SUMS'
c29556a2719bf613ef3d5e070e40d903a8965d9c081beca1375dc1e6e0f93c23  FiraSans-Regular.ttf
cbc1842cbed8c1d1146ba7c9db97d8f28c9bedfd25f41c5b0e1259ca48622328  FiraSans-Medium.ttf
db0321f83eb3e9f527b8af384a1b3fefdc1039cf2b06fd39b3f61492bda9561c  FiraSans-SemiBold.ttf
a4d8e149ecdd4874a0726eb0af894488b3b31c423d6b0017c8f415ed1b795b45  FiraSans-Bold.ttf
SUMS

for f in FiraSans-Regular.ttf FiraSans-Medium.ttf FiraSans-SemiBold.ttf FiraSans-Bold.ttf; do
    curl -fsSL -o "$tmp/$f" "$base/$f"
done
(cd "$tmp" && sha256sum -c SHA256SUMS)

mkdir -p "$dest"
cp "$tmp"/*.ttf "$dest"/
fc-cache -f "$dest" >/dev/null 2>&1 || true
echo "Fira Sans installed to $dest"
