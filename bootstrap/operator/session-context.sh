#!/bin/bash
# session-context.sh — SessionStart hook of the operator Claude workspace (~/xcloud/operator).
# Syncs both repositories (xcloud-sync), then prints a short digest that Claude Code adds to the session:
# docs and state revisions, proposals waiting for the operator's signature, every agent's phase, and open
# hand-offs to the operator. Points to files instead of pasting them; stays under the 10,000-character
# hook limit; never fails the session.
set -uo pipefail
XC=${XCLOUD_HOME:-$HOME/xcloud}
D=$XC/xcloud-docs S=$XC/xcloud-state MAX=8000
cat >/dev/null 2>&1 || true   # hook input (unused)
field() { sed -n "s/^$1:[[:space:]]*\([^#]*[^[:space:]#]\).*/\1/p" "$2" 2>/dev/null | head -n1; }
out=$(
  echo "## xcloud operator context ($(date -Is), $(hostname -s))"
  PATH="$HOME/.local/bin:$PATH" timeout 60 xcloud-sync 2>&1 || echo "sync: xcloud-sync failed or timed out"

  echo; echo "### proposals waiting for the operator (only the operator runs xcloud-approve)"
  n=0
  while read -r sha ref subj; do
    [[ -n $sha ]] || continue
    echo "- ${ref#refs/remotes/origin/} ${sha:0:12} — $subj → operator: xcloud-approve ${sha:0:12}"; n=$((n + 1))
  done < <(git -C "$D" for-each-ref --format='%(objectname) %(refname) %(contents:subject)' 'refs/remotes/origin/proposals/' 2>/dev/null)
  (( n )) || echo "none"

  echo; echo "### agents (xcloud-state/agents/*/status.md)"
  for f in "$S"/agents/*/status.md; do
    [[ -f $f ]] || continue
    echo "- $(basename "$(dirname "$f")"): phase $(field phase "$f") · updated $(field updated "$f") · host $(field host "$f") · docs $(field docs "$f")"
  done

  echo; echo "### open hand-offs to operator"
  n=0
  for f in "$S"/handoff/*.md; do
    [[ -f $f && ${f##*/} != README.md && $(field to "$f") == operator ]] || continue
    s=$(field status "$f"); [[ $s == open || $s == accepted ]] || continue
    echo "- ${f#"$XC"/} (from $(field from "$f"), $s, blocking $(field blocking "$f"))"; n=$((n + 1))
    (( n >= 20 )) && { echo "- … more in $S/handoff/"; break; }
  done
  (( n )) || echo "none"
)
(( ${#out} > MAX )) && out="${out:0:MAX}"$'\n'"[digest truncated at $MAX characters]"
printf '%s\n' "$out"
exit 0
