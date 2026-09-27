#!/bin/bash
# xcloud-gg/dotfiles — one-line installer for Debian 13 and Arch.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) [MODE] [OPTIONS]
#
# MODE (asked for when omitted on a terminal):
#   dotfiles    this repository's X11/i3 rice for the current user, through chezmoi (default)
#   operator    operator workstation (loki today, thor later): gh, Claude Code, ~/xcloud with xcloud-docs and
#               xcloud-state kept current (signed commits only), xcloud-approve, and an operator Claude
#               workspace that loads the current build state at every session start
#   agent-host  an xCloud agent host NOT installed from the live ISO: fetches the agent kit from a signed
#               kit-* tag of xc0-sh/xcloud-docs, verifies it against the fingerprint you type, and runs
#               bootstrap-host.sh (needs sudo)
#
# Options for every mode:  --ref REF   branch, tag or commit of this repository to use (default main).
# Pin a commit for anything that matters: …/dotfiles/<commit>/install.sh and --ref <commit>.
# Mode options:  bootstrap/<mode>.sh --help.  Everything runs from main() at the end, so a download
# cut short runs nothing.
set -euo pipefail

REPO=${XCLOUD_DOTFILES_REPO:-https://github.com/xcloud-gg/dotfiles.git}   # override only to test a fork or a local clone

usage() {  # the file may be a pipe (bash <(curl …)), so the help text is inline rather than read back
  cat <<'HELP'
usage: bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) [MODE] [--ref REF] [OPTIONS]
  dotfiles     the X11/i3 rice for the current user (chezmoi)           [default]
  operator     operator workstation: gh, Claude Code, ~/xcloud, xcloud-approve   (… operator --help)
  agent-host   agent host from a signed kit tag, then bootstrap-host.sh          (… agent-host --help)
HELP
  exit 2
}

fetch_repo() {  # DIR REF — clone this repository at REF (branch, tag or commit)
  local dir=$1 ref=$2
  if git clone -q --depth 1 --branch "$ref" "$REPO" "$dir" 2>/dev/null; then return 0; fi
  git clone -q "$REPO" "$dir" && git -C "$dir" checkout -q --detach "$ref"
}

dotfiles_mode() {  # chezmoi + this repository for the current user
  local ref=$1 src
  [[ $EUID -ne 0 ]] || die "run the dotfiles mode as the desktop user, not root"
  pkgs git curl ca-certificates -- git curl ca-certificates
  if ! command -v chezmoi &>/dev/null; then
    if [[ $FAM == arch ]]; then pkgs -- chezmoi
    else
      say "chezmoi (upstream installer → ~/.local/bin; not packaged in trixie)"
      local ci; ci=$(mktemp)
      curl -fsSL https://get.chezmoi.io -o "$ci" \
        || curl -fsSL https://raw.githubusercontent.com/twpayne/chezmoi/master/assets/scripts/install.sh -o "$ci" \
        || die "cannot download the chezmoi installer"
      sh "$ci" -b "$HOME/.local/bin"; rm -f "$ci"
      export PATH="$HOME/.local/bin:$PATH"
      command -v chezmoi &>/dev/null || die "chezmoi did not install"
    fi
  fi
  src=$(chezmoi source-path 2>/dev/null || echo "$HOME/.local/share/chezmoi")
  if [[ -d $src/.git ]]; then
    say "updating $src"
    git -C "$src" fetch -q origin && git -C "$src" checkout -q "$ref" && { git -C "$src" merge -q --ff-only "origin/$ref" 2>/dev/null || true; }
  else
    say "cloning xcloud-gg/dotfiles@$ref into $src"
    fetch_repo "$src" "$ref"
  fi
  say "chezmoi apply"
  chezmoi init --apply
  echo "done — log out and back in (or start i3) to pick up the desktop configuration."
}

main() {
  local mode="" ref=main args=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      dotfiles|operator|agent-host) [[ -z $mode ]] || usage; mode=$1; shift ;;
      --ref) ref=${2:?--ref needs a value}; shift 2 ;;
      -h|--help) [[ -n $mode ]] && { args+=("$1"); shift; } || usage ;;
      *) args+=("$1"); shift ;;
    esac
  done
  if [[ -z $mode ]]; then
    if [[ -t 0 ]]; then
      echo "xcloud-gg/dotfiles installer — what should this machine get?"
      PS3="choose 1-3: "
      select mode in dotfiles operator agent-host; do [[ -n $mode ]] && break; done
    else mode=dotfiles; fi
  fi
  command -v git &>/dev/null || { command -v apt-get &>/dev/null && sudo apt-get install -y -q git; } || { command -v pacman &>/dev/null && sudo pacman -S --needed --noconfirm git; }
  W=$(mktemp -d); trap 'rm -rf "$W"' EXIT   # global: the trap runs after main() returns
  fetch_repo "$W/dotfiles" "$ref" || { echo "cannot fetch $REPO@$ref" >&2; exit 1; }
  # shellcheck source=bootstrap/lib.sh
  . "$W/dotfiles/bootstrap/lib.sh"
  detect_os
  echo "xcloud-gg/dotfiles@$(git -C "$W/dotfiles" rev-parse --short=12 HEAD) · mode $mode · $FAM"
  case $mode in
    dotfiles) dotfiles_mode "$ref" ;;
    operator) bash "$W/dotfiles/bootstrap/operator.sh" "${args[@]}" ;;
    agent-host)
      if [[ $EUID -eq 0 ]]; then bash "$W/dotfiles/bootstrap/agent-host.sh" "${args[@]}"
      else sudo bash "$W/dotfiles/bootstrap/agent-host.sh" "${args[@]}"; fi ;;
  esac
}

main "$@"
