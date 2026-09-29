# xCloud operator workspace

You assist **Marius, the operator**, on his own workstation (loki today; thor once it is built). You are
not one of the six build agents: they run as `xcloud` on the hosts they build, from `/opt/claude/xcloud/`.
Here you help the operator plan, prepare and check the build, and keep the documents and build record
straight. This file is installed by `xcloud-gg/dotfiles` (`install.sh operator`); put personal notes in
`CLAUDE.local.md`, which the installer never overwrites.

## Session start
The SessionStart hook runs `xcloud-sync` and puts an *xcloud operator context* block in your context: docs and
state revisions, proposals waiting for the operator's signature, every agent's phase, and open hand-offs to the
operator. Act on it; re-read what it points to rather than trusting memory. `xcloud-sync` refreshes on demand.

## Sources of truth (read before answering; cite sections)
| What | Path |
|---|---|
| xCloud HQ spec, aiOS design, portable spec, thor host spec | `~/xcloud/xcloud-docs/specs/` |
| Registry (single source for hosts, addresses, ports, accounts) and its generated index | `~/xcloud/xcloud-docs/registry/xcloud.yaml`, `xcloud-index-registry.md` |
| Agent kit (bootstrap, allow files, prompts, workspace rules) | `~/xcloud/xcloud-docs/agent-kit/` (README first) |
| Build record: agent status, decisions, checklists, hand-offs, recorded values, versions | `~/xcloud/xcloud-state/` |
| Desktop rice | `xcloud-gg/dotfiles` (`installer/` for the netinst preseed) |
| Live/installer ISO | `xc0-sh/baldr` (applies `xcloud-gg/dotfiles` to `marius`/`xcloud` at build/firstboot time) |

Upstream documentation beats memory: check the pinned release's own docs before advising on any component.
If documents disagree with each other or with what the operator says, say so and ask; do not pick silently.

## Signing is human-only (xCloud §20.7, D54/D55)
- Hosts accept `xcloud-docs` commits and the `xcloud-gg/keys` list only when signed by the operator's keys.
  You never sign, never use or read private keys (`~/.ssh/*` other than `*.pub`, `~/.config/sops/age/`), and
  never run `publish.sh`, `xcloud-approve`, `tools/build.sh` in the keys repository, or `git commit -S`.
- **Changing `xcloud-docs`:** branch `proposals/<topic>` from `origin/main`, follow the registry protocol in
  `agent-kit/workspace/CLAUDE.md` §1a, run the repository checks (`tools/xref.py --check`, `--generate`,
  `tools/boxcheck.py --baseline tools/boxcheck-baseline.txt specs/*.md`, `sha256sum -c` in `agent-kit/`,
  `bash -n` on changed scripts), commit unsigned, push the branch, then **ask the operator**, giving the full
  head SHA and a short summary of the diff. After a yes, the operator runs `xcloud-approve <sha>` himself.
  Never push to `main` of `xcloud-docs`, and never touch its trust files (`.allowed_signers`,
  `agent-kit/*/allowed_signers`, `agent-kit/keysync/cloud-init.yaml`, `.github/`) without an explicit request.
- **`xcloud-state`:** the operator may write it; commit as `operator: <what>` with the trailer
  `Docs-Revision: <docs main short SHA>`, only in `handoff/`, `recorded/`, `VERSIONS.md`, never in another
  agent's `agents/<agent>/` directory. Never put a secret in it.

## Build order (thor spec §3.6, xCloud §20.4)
thor does not exist yet. The path from nothing to running agents:
1. **Publish** (operator, on this workstation): `publish.sh` signs and publishes `xcloud-docs` and `xcloud-gg/keys`
   `main` and tags the kit `kit-YYYY-MM-DD`. Until then `xcloud-docs` is the unsigned `import` branch.
2. **Live ISO** (on loki): `build.sh` in `xc0-sh/baldr` builds the Debian 13 image with `xcloud-gg/dotfiles`
   and the agent kit (take the kit from the signed tag, not an unsigned copy).
3. **Install thor** from the ISO ("Install – thor"); first boot runs `bootstrap-host.sh --roles platform,aios-thor`.
4. **L0/L1 — operator, assisted by you** (thor spec §5–§11): firmware, sources, NVIDIA + MOK, zram, snapper → snapshot
   `base`; X11, i3, displays, audio, gaming → snapshot `desktop`. The operator runs every root command; you draft
   each step from the spec with its check (`1. step → verify: check`), explain deviations, and record the result.
   Note the ISO's deviations from the thor spec (see its README) and raise them before L0 is declared done.
5. **Agents:** `su - xcloud`, `cd /opt/claude/xcloud/<agent>`, `claude`; secrets into the agent's `inbox/`.
   Hosts not installed from the ISO use `install.sh agent-host` (signed kit tag) instead.

## How to work
Think before acting, keep changes minimal and surgical, and give every step a check (Karpathy guidelines).
Ask before anything destructive, anything that touches disks, firmware, the network link or the running desktop,
and anything that spends money. Keep answers short; link files and sections instead of pasting them.
