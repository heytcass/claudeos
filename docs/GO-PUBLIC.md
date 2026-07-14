# Go-Public Runbook

The checklist for flipping this repo from private to public, produced by the
2026-07-13 security audit (full tree + all 231 commits of history + GitHub
settings + workflow supply chain). Items are ordered: **blocking** items must
be done *before* the visibility flip, **at-flip** items the moment it happens,
**recommended** items soon after.

## Audit verdict

The working tree is publishable. The git history is not: it contains one real
API key and one real human-chosen password. Because the repo has never been
public, a history rewrite now is cheap and permanently effective — after
publication it never is (GitHub keeps dangling commits fetchable by SHA
forever, and secret scanners crawl new public repos within minutes).

## Blocking — before the flip

### 1. Verify the UniFi API key rotation

Commit `07eadf2` (2026-03-09) committed `.mcp.json` with a live UniFi
controller API key; it was removed in `ec68221` (2026-06-11) with a commit
message asserting the key was rotated. **Verify that in the UniFi console**
(admin → control plane → integrations/API): the leaked key
(`nwoao1XA-…`) must be absent from the active key list. If it is still
active, rotate it now. The controller is LAN-only (`10.0.0.1`), which limits
exploitability, but a live admin credential in a public repo is a hard no.

### 2. Check the historical password for reuse

Commits `043864b` / `5402f27` (2026-07-05..07) committed
`.claude/settings.local.json` containing `SSHPASS='!n$tall!'` — the temporary
password of the NixOS *live installer* session during the transporter
reinstall. The credential itself is dead (that session no longer exists), but
it is a human-chosen password. **If that password or its pattern is in use
anywhere else, change it there first.**

### 3. Rewrite history

One `git filter-repo` pass scrubs both leaks (and the unused personal photo,
if desired). From a **fresh clone** (filter-repo refuses to run in a dirty
working copy):

```bash
# replacements.txt:
#   nwoao1XA-U0AoIIrcdLF-eKm646R9M9I==>REDACTED-UNIFI-KEY
#   !n$tall!==>REDACTED-PASSWORD
git clone git@github.com:heytcass/claudeos.git claudeos-rewrite
cd claudeos-rewrite
git filter-repo --replace-text replacements.txt          # scrub the two literals
git filter-repo --invert-paths --path assets/avatar.jpg  # drop the photo's blobs (optional)
git push --force --all && git push --force --tags
```

Aftermath (the disruptive part — plan for it):

- **Both machines must re-clone** (or hard-reset) `~/.config/claudeos`; every
  local branch and worktree references pre-rewrite SHAs.
- The on-machine auto-update lane pulls from the repo — it will fail until the
  local checkout is reset. Do the rewrite and the resets in one sitting.
- Any open PRs are orphaned by the rewrite; merge or close them first.
- Old SHAs referenced in docs/commit messages (e.g. generation names) become
  cosmetic dangling references — harmless.

### 4. Land the workflow hardening (this PR)

Done in the same PR that adds this file:

- `claude.yml` — actor gate (`author_association` ∈ OWNER/MEMBER/COLLABORATOR)
  so a stranger's `@claude` issue can't invoke the OAuth-token-bearing agent.
- `claude-code-review.yml` — same-repo PRs only; fork PRs become a no-op
  instead of a red check.
- `heal-automerge.yml` — `path`/`churn` moved into `env:`; go-public revisit
  conclusion recorded in the header (the rung-2 design holds for a public repo).
- All `uses:` SHA-pinned across all five workflows.
- `assets/avatar.jpg` deleted (unused; carried EXIF with camera body/lens
  serials and photographer identity).
- `.claude/scheduled_tasks.lock` untracked (machine-local session state).

## At the flip — settings that only exist once public

Do these **immediately after** changing visibility (Settings → Actions →
General, or the API calls below):

1. **Fork PR workflow approval → "Require approval for all outside
   collaborators."** GitHub's default only gates first-time contributors — one
   merged typo-fix and an attacker gets free workflow runs.

   ```bash
   gh api -X PUT repos/heytcass/claudeos/actions/permissions/fork-pr-contributor-approval \
     -f approval_policy=all_external_contributors
   ```

2. **Require SHA pinning** (the pins land in this PR, so this can be enforced):

   ```bash
   gh api -X PUT repos/heytcass/claudeos/actions/permissions \
     -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
   ```

3. **Enable secret scanning + push protection** (free for public repos):
   Settings → Code security → enable both.

## Recommended — soon after

- **Restrict `allowed_actions`** from `all` to verified/selected creators.
- **Fix the sops recipient gap:** gti's host key is not in `.sops.yaml`, so
  gti cannot decrypt at runtime (see `docs/SECRETS.md`, Known gap).
- **Pin `.mcp.json` server versions** — `@upstash/context7-mcp@latest` (npx)
  and `unifi-mcp-server` (uvx) resolve unpinned at every launch on the
  machines; the UniFi one also sets `VERIFY_SSL: false`. Unchanged by going
  public, but the pattern will be on display.
- **Mind the transitive supply chain:** `heytcass/claude-desktop-linux-flake`
  is a flake input auto-pulled weekly by the update bot; its branch hygiene is
  effectively part of this repo's supply chain.
- **`has_issues` is on** — that's the surface `claude.yml`'s actor gate
  protects; keep the gate if you keep public issues.

## Verified clean (no action)

- `secrets/secrets.yaml`: sops/age-encrypted in **every** historical revision;
  no age private key material anywhere in history.
- sops consumption is runtime-only (`/run/secrets/*`, mode 0400) — no secret
  ever enters the world-readable Nix store at eval time.
- Full-history pattern sweep (`ghp_`, `github_pat_`, `AKIA`, `sk-ant-`,
  private key blocks, `xox*`, `AIza`, JWTs, `user:pass@` URLs): clean apart
  from items 1–2 above.
- Flake inputs all resolve through `flake.lock`; no unhashed fetches.
- Repo settings: default workflow token is read-only, no deploy keys, no
  webhooks, single Actions secret (`CLAUDE_CODE_OAUTH_TOKEN`), owner is the
  only collaborator, no `pull_request_target` anywhere.
- Identity disclosure (name, email, timezone, RFC1918 IPs, SSH/age *public*
  keys, hostnames `gti`/`transporter`): accepted as public by design — none of
  it is actionable, and commit authorship can't be hidden anyway.
