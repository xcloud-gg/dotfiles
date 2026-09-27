# bootstrap/lib.sh — shared helpers for install.sh modes (sourced, not executed)
# shellcheck shell=bash

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# FAM=debian|arch, from /etc/os-release
detect_os() {
  [[ -r /etc/os-release ]] || die "no /etc/os-release — Debian 13 or Arch only"
  # shellcheck disable=SC1091
  . /etc/os-release
  case " $ID ${ID_LIKE:-} " in
    *" arch "*) FAM=arch ;;
    *" debian "*) FAM=debian ;;
    *) die "unsupported OS: $ID (Debian 13 or Arch)" ;;
  esac
}

# as_root CMD... — run as root (directly, or through sudo)
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# pkgs DEBIAN_NAMES -- ARCH_NAMES — install whatever is missing
pkgs() {
  local deb=() arch=() seen=0
  for p in "$@"; do [[ $p == -- ]] && { seen=1; continue; }; (( seen )) && arch+=("$p") || deb+=("$p"); done
  if [[ $FAM == debian ]]; then
    local miss=(); for p in "${deb[@]}"; do dpkg -s "$p" &>/dev/null || miss+=("$p"); done
    (( ${#miss[@]} )) || return 0
    as_root apt-get update -q && as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "${miss[@]}"
  else
    as_root pacman -S --needed --noconfirm "${arch[@]}"
  fi
}

# ask "question" — yes/no on the terminal, default no; true when yes
ask() { local a; [[ -t 0 ]] || return 1; read -r -p "$1 [y/N] " a; [[ $a =~ ^[Yy] ]]; }

# pin_signer "KEY" FINGERPRINT OUTFILE [NAMESPACES] — write an allowed_signers file for KEY, but only if KEY's
# fingerprint equals the one the operator typed from their own records (never take it from a download).
pin_signer() {
  local key=$1 fpr=$2 out=$3 ns=${4:-git} got
  [[ -n $key && -n $fpr ]] || die "--signer-key and --fingerprint are both required"
  got=$(ssh-keygen -lf /dev/stdin <<<"$key" 2>/dev/null | awk '{print $2}') || true
  [[ -n $got ]] || die "--signer-key is not a valid SSH public key"
  [[ $got == "$fpr" ]] || die "signer fingerprint mismatch: key has $got, you typed $fpr"
  printf '* namespaces="%s" %s\n' "$ns" "$(cut -d' ' -f1,2 <<<"$key")" >"$out"
}

# install_claude [stable|latest|X.Y.Z] — Claude Code for the current user, native installer (auto-updates)
install_claude() {
  if command -v claude &>/dev/null || [[ -x $HOME/.local/bin/claude ]]; then return 0; fi
  say "Claude Code (native installer, ${1:-stable})"
  curl -fsSL https://claude.ai/install.sh -o "${TMPDIR:-/tmp}/claude-install.sh"
  bash "${TMPDIR:-/tmp}/claude-install.sh" "${1:-stable}"
  rm -f "${TMPDIR:-/tmp}/claude-install.sh"
}
