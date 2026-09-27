#!/bin/bash
# operator.sh — set up (or refresh) the operator workstation. Run through install.sh:
#   bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) operator [OPTIONS]
#
# Options:
#   --dir DIR                where the checkouts and the operator workspace live (default ~/xcloud)
#   --signer-key "KEY"       the operator's git commit-signing PUBLIC key that xcloud-docs main must be signed
#   --fingerprint SHA256:…   with, and its fingerprint typed from your own records. Default: your own
#                            git user.signingkey (you confirm its fingerprint).
#   --claude-version V       stable (default), latest, or X.Y.Z
#
# Does, idempotently: git/gh/jq/python3-yaml/ssh-keygen; Claude Code; gh login; SSH commit signing check;
# ~/xcloud/{xcloud-docs,xcloud-state} (docs only across signed commits — xcloud-sync); xcloud-sync and
# xcloud-approve on PATH; the operator Claude workspace ~/xcloud/operator (CLAUDE.md, SessionStart hook).
# It never creates, reads, or moves a private key, and never applies the X11/i3 rice.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
XC=$HOME/xcloud SKEY="" SFPR="" CV=stable
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) XC=${2:?}; shift 2 ;;
    --signer-key) SKEY=${2:?}; shift 2 ;;
    --fingerprint) SFPR=${2:?}; shift 2 ;;
    --claude-version) CV=${2:?}; shift 2 ;;
    *) sed -n '2,15p' "$0"; exit 2 ;;
  esac
done
[[ $EUID -ne 0 ]] || die "run the operator mode as your own user (it uses sudo for packages only)"
detect_os
XC=$(realpath -m "$XC")

say "packages"
pkgs git gh jq curl ca-certificates openssh-client python3 python3-yaml \
  -- git github-cli jq curl ca-certificates openssh python python-yaml

install_claude "$CV"
export PATH="$HOME/.local/bin:$PATH"

say "GitHub login (gh)"
gh auth status -h github.com &>/dev/null || gh auth login -h github.com -p https -w
gh auth setup-git -h github.com

say "commit signing (SSH)"
if [[ $(git config --global gpg.format || true) != ssh || -z $(git config --global user.signingkey || true) ]]; then
  warn "git has no SSH signing key configured. xcloud-approve and publish.sh sign with it. Set it up yourself, e.g.:"
  echo "  git config --global gpg.format ssh && git config --global user.signingkey ~/.ssh/id_ed25519.pub"
  echo "  (a hardware key — ssh-keygen -t ed25519-sk — keeps it out of reach of any process on this machine)"
fi

say "pinned signer for xcloud-docs"
install -d -m 0700 "$HOME/.config/xcloud"
SIGNERS=$HOME/.config/xcloud/docs.allowed_signers
if [[ -n $SKEY || -n $SFPR ]]; then
  pin_signer "$SKEY" "$SFPR" "$SIGNERS"
elif [[ -s $SIGNERS ]]; then
  echo "kept $SIGNERS"
elif sk=$(git config --global user.signingkey 2>/dev/null) && [[ -f ${sk/#\~/$HOME} ]]; then
  sk=${sk/#\~/$HOME}; [[ $sk == *.pub ]] || sk=$sk.pub
  echo "your signing key: $(ssh-keygen -lf "$sk")"
  if ask "Pin this key as the signer of xcloud-docs main (compare the fingerprint with your password manager)?"; then
    pin_signer "$(cat "$sk")" "$(ssh-keygen -lf "$sk" | awk '{print $2}')" "$SIGNERS"
  fi
fi
[[ -s $SIGNERS ]] && echo "signer: $(ssh-keygen -lf "$SIGNERS" 2>/dev/null | awk '{print $2}' || cut -c1-60 "$SIGNERS")" \
  || warn "no pinned signer — xcloud-sync will not advance xcloud-docs main until you re-run with --signer-key/--fingerprint"

say "checkouts in $XC"
install -d "$XC"
for r in xcloud-docs xcloud-state; do
  if [[ ! -d $XC/$r/.git ]]; then
    if [[ $r == xcloud-docs ]] && gh api "repos/xc0-sh/$r/branches/main" &>/dev/null; then
      # empty repository: xcloud-sync fetches, verifies every commit on main, and only then checks it out
      git init -q -b main "$XC/$r" && git -C "$XC/$r" remote add origin "https://github.com/xc0-sh/$r.git"
    elif [[ $r == xcloud-state ]] && gh api "repos/xc0-sh/$r/branches/main" &>/dev/null; then
      git clone -q "https://github.com/xc0-sh/$r.git" "$XC/$r"
    elif [[ $r == xcloud-docs ]] && gh api "repos/xc0-sh/$r/branches/import" &>/dev/null; then
      git clone -q --branch import "https://github.com/xc0-sh/$r.git" "$XC/$r"
    else die "cannot reach xc0-sh/$r (does your gh login have access to xc0-sh?)"; fi
  fi
done
install -d "$HOME/.local/bin"
install -m 0755 "$HERE/operator/xcloud-sync" "$HOME/.local/bin/xcloud-sync"
XCLOUD_HOME=$XC xcloud-sync
if [[ -f $XC/xcloud-docs/tools/xcloud-approve ]]; then ln -sfn "$XC/xcloud-docs/tools/xcloud-approve" "$HOME/.local/bin/xcloud-approve"
else echo "xcloud-approve: not in this revision of xcloud-docs yet (arrives with the first approved proposal; until then run it from the proposal checkout)"; fi

say "operator Claude workspace $XC/operator"
install -d "$XC/operator/.claude/hooks"
install -m 0644 "$HERE/operator/CLAUDE.md" "$XC/operator/CLAUDE.md"
install -m 0755 "$HERE/operator/session-context.sh" "$XC/operator/.claude/hooks/session-context.sh"
sed "s|@XC@|$XC|g" "$HERE/operator/settings.json" >"$XC/operator/.claude/settings.json.new"
jq empty "$XC/operator/.claude/settings.json.new" && mv "$XC/operator/.claude/settings.json.new" "$XC/operator/.claude/settings.json"
[[ -f $XC/operator/CLAUDE.local.md ]] || printf '# Personal notes (never overwritten by the installer)\n' >"$XC/operator/CLAUDE.local.md"
XCLOUD_HOME=$XC "$XC/operator/.claude/hooks/session-context.sh" </dev/null | head -n 25

cat <<NEXT

Done. Start the operator assistant:   cd $XC/operator && claude
Refresh the checkouts any time:        xcloud-sync
Approve a proposal (you, not Claude):  xcloud-approve <sha>
NEXT
