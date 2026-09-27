#!/bin/bash
# agent-host.sh — turn an existing Debian 13 / Arch machine into an xCloud agent host from a SIGNED kit tag.
# Hosts installed from the live ISO do not need this (xcloud-firstboot runs bootstrap-host.sh). Run through:
#   bash <(curl -fsSL https://raw.githubusercontent.com/xcloud-gg/dotfiles/main/install.sh) agent-host \
#        --roles aios-debian --operator-key ~/.ssh/id_ed25519.pub \
#        --signer-key "ssh-ed25519 AAAA… marius" --fingerprint SHA256:…
#
#   --roles R,…            platform, aios-core, aios-thor, aios-debian, aios-arch, aios-portable (default: from hostname)
#   --operator-key FILE    public key that may log in as xcloud until keysync takes over (required)
#   --signer-key / --fingerprint   the operator's git commit-signing public key and its fingerprint, typed
#                          from your own records — the kit tag must be signed by it (required)
#   --tag kit-YYYY-MM-DD   kit tag of xc0-sh/xcloud-docs (default: the newest kit-* tag)
#   --claude-version V     stable (default), latest, or X.Y.Z
#   --no-deploy-keys       do not offer to register this host's GitHub deploy keys
#
# Uses a throwaway gh login (your account, device flow) to read the private repository and to add the two
# deploy keys; the login is removed at the end. Keeps the verified checkout in /root/xcloud-docs-<tag>:
# re-running bootstrap-host.sh from it is how permissions change later (runbook RB-23).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
ROLES="" OPKEY="" SKEY="" SFPR="" TAG="" CV=stable DEPLOY=1
while [[ $# -gt 0 ]]; do
  case $1 in
    --roles) ROLES=${2:?}; shift 2 ;;
    --operator-key) OPKEY=${2:?}; shift 2 ;;
    --signer-key) SKEY=${2:?}; shift 2 ;;
    --fingerprint) SFPR=${2:?}; shift 2 ;;
    --tag) TAG=${2:?}; shift 2 ;;
    --claude-version) CV=${2:?}; shift 2 ;;
    --no-deploy-keys) DEPLOY=0; shift ;;
    *) sed -n '2,18p' "$0"; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || die "run as root (install.sh re-runs this mode through sudo)"
[[ -f $OPKEY ]] && ssh-keygen -lf "$OPKEY" &>/dev/null || die "--operator-key must be a public key file"
if [[ -z $ROLES ]]; then
  case $(hostname -s) in thor) ROLES=platform,aios-thor ;; odin) ROLES=aios-core ;; baldr) ROLES=aios-portable ;; *) ROLES=aios-debian ;; esac
  [[ -f /etc/arch-release ]] && ROLES=aios-arch
  echo "roles from hostname $(hostname -s): $ROLES"; ask "Use these roles?" || die "give --roles"
fi
detect_os

say "packages"
pkgs git gh curl ca-certificates openssh-client -- git github-cli curl ca-certificates openssh

W=$(mktemp -d); chmod 0700 "$W"
export GH_CONFIG_DIR=$W/gh
cleanup() { gh auth logout -h github.com &>/dev/null || true; rm -rf "$W"; }
trap cleanup EXIT

say "pinned signer (the kit tag must be signed by it)"
pin_signer "$SKEY" "$SFPR" "$W/allowed_signers"
echo "signer $SFPR"

say "temporary GitHub login (removed at the end)"
gh auth login -h github.com -p https -w
GIT=(git -c credential.helper= -c "credential.helper=!gh auth git-credential")
URL=https://github.com/xc0-sh/xcloud-docs.git
if [[ -z $TAG ]]; then
  TAG=$("${GIT[@]}" ls-remote --tags --refs "$URL" 'kit-*' | awk '{print $2}' | sed 's|refs/tags/||' | sort -V | tail -n1)
  [[ -n $TAG ]] || die "no kit-* tag in xc0-sh/xcloud-docs yet (publish.sh creates the first one)"
fi
[[ $TAG =~ ^kit-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "bad --tag $TAG"
DST=/root/xcloud-docs-$TAG

say "kit $TAG → $DST"
if [[ ! -d $DST/.git ]]; then "${GIT[@]}" clone -q --depth 1 --branch "$TAG" "$URL" "$DST"; fi
git -C "$DST" -c gpg.ssh.allowedSignersFile="$W/allowed_signers" verify-tag "$TAG" \
  || { rm -rf "$DST"; die "tag $TAG is NOT signed by $SFPR — kit discarded"; }
[[ $(git -C "$DST" rev-parse HEAD) == $(git -C "$DST" rev-parse "$TAG^{commit}") ]] || die "$DST is not at $TAG"
(cd "$DST/agent-kit" && sha256sum -c --quiet SHA256SUMS) || die "kit checksums do not match"
echo "verified: tag $TAG signed by $SFPR, checksums OK"

say "bootstrap-host.sh --roles $ROLES"
"$DST/agent-kit/bootstrap/bootstrap-host.sh" --roles "$ROLES" --operator-key "$OPKEY" --claude-version "$CV"

if (( DEPLOY )) && [[ -f /etc/xcloud/deploy/xcloud-docs_ed25519.pub ]] && ask "Register this host's two deploy keys on GitHub now?"; then
  h=$(hostname -s)
  gh repo deploy-key add /etc/xcloud/deploy/xcloud-docs_ed25519.pub --repo xc0-sh/xcloud-docs --title "$h docs (read-only)" || true
  gh repo deploy-key add /home/xcloud/.ssh/xcloud-state_ed25519.pub --repo xc0-sh/xcloud-state --title "$h state" --allow-write || true
  "$DST/agent-kit/sync/install.sh" || warn "repository sync not ready — see above"
fi

cat <<NEXT

Kit kept at $DST (re-run bootstrap-host.sh from there for permission changes, RB-23).
Sign Claude Code in as xcloud:  su - xcloud, then claude (browser login), or on a machine with a browser run
  claude setup-token  and put the token in xcloud's environment as CLAUDE_CODE_OAUTH_TOKEN. Make sure no
  ANTHROPIC_API_KEY is set for xcloud: it would silently take precedence over the subscription token.
NEXT
