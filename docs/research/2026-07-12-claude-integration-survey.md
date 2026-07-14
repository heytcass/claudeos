# Claude Integration Survey — MCPs, Skills, Plugins, and Agentic Practice (2026-07-12)

A deep dive into the ecosystem around "Claude at the system level," prompted by
the question: *are there Nix/NixOS-specific MCPs we should be leveraging — a
NixOS wiki MCP? — plus skills, plugins, and latest LLM practices?* Two research
passes fed this: a full map of the existing claudeos integration surface, and a
web survey of the mid-2026 ecosystem.

## TL;DR

1. **The NixOS wiki MCP exists and we (thought we) already had it.**
   `utensils/mcp-nixos` v2.4.x bundles NixOS Wiki search, noogle, NixHub,
   FlakeHub, and options/packages for NixOS + home-manager + darwin + nixvim —
   consolidated into two tools. It's now pinned as a flake input.
2. **Both "our" MCP servers were dead config.** The `~/.claude/.mcp.json` seed
   path is one Claude Code never reads, and `mcp-system-health` spoke the wrong
   stdio framing anyway. Both are fixed and registered in the repo's tracked
   `.mcp.json` (see "What changed" below).
3. The biggest *novel* win wasn't in the ecosystem — it was wrapping our own
   runtime-validation workflow (`hyprctl`/`qs` checks that `nix build` can't
   do) as MCP tools.
4. Nothing else in the plugin/skill marketplaces is worth adopting for a
   self-maintaining NixOS system today; the leverage is in writing our own
   (which claudeos already does: 5 agents, 4+ skills, 3 hooks, 7 lanes).

## What changed in this PR

- `mcp-nixos` pinned as a flake input; binary installed via
  `home/claude-code.nix`; the weekly auto-update lane keeps it fresh.
- `mcp-system-health` rewritten to newline-delimited JSON-RPC (the MCP stdio
  spec; the old LSP-style `Content-Length` framing meant Claude Code could
  never connect — it had been silently unreachable since it was written).
- Both servers registered in the repo-root `.mcp.json` (project scope, tracked,
  Ring 1). The `~/.claude/.mcp.json` seed in `home/claude-code.nix` was
  removed as dead code. The stale seeded file can be deleted from `~/.claude/`
  on both machines; nothing reads it.
- Three new `system-health` tools: `hypr_config_check`, `hypr_config_errors`,
  `quickshell_check` — the CLAUDE.md "validate against the running binary"
  workflow, now callable by any agent in the repo.

## MCP ecosystem for Nix/NixOS

### mcp-nixos — ADOPTED (pinned input)

- **Source:** [utensils/mcp-nixos](https://github.com/utensils/mcp-nixos)
  (James Brink), v2.4.3 as of April 2026, actively maintained, ~750 stars.
- **Surface:** two consolidated tools (down from 17 — deliberate
  token-efficiency redesign, ~1,030 tokens of schema):
  - `nix` — unified search/info over 130K+ packages, 23K+ NixOS options,
    home-manager/darwin/nixvim options, 2K+ Nix functions (noogle.dev),
    600+ FlakeHub flakes, NixOS Wiki, nix.dev.
  - `nix_versions` — package version history with nixpkgs commit hashes
    (NixHub.io). "Which nixpkgs pin had postgresql 15" is one call.
- **Notes:** queries live APIs (search.nixos.org Elasticsearch, NixHub) — no
  local Nix evaluation, works offline-ish only for cached queries. Verified
  locally: handshake requires `notifications/initialized` before `tools/list`.
- **Why pinned instead of `nix run github:...`:** server startup previously
  needed network + flake eval every time; a pinned input is instant,
  reproducible, and still fresh via the weekly `nix flake update` lane. Its
  own `flake.lock` is kept (no `nixpkgs.follows`) — upstream CI tests that
  exact pin, and Python package sets break easily across nixpkgs versions.

### nix-sandbox-mcp — DEFERRED (backlog #13)

[SecBear/nix-sandbox-mcp](https://github.com/SecBear/nix-sandbox-mcp):
sandboxed code execution via bubblewrap + namespaces, environments declared as
flake expressions, one `run` tool. Exactly the mechanical-safety shape the
constitution prefers for autonomous lanes, but early-stage as of this survey.
Re-evaluate when it matures, or prototype the idea in-house (~50 lines of bash
around `bwrap`).

### Not adopting

- **llm-agents.nix** ([numtide](https://github.com/numtide/llm-agents.nix)) —
  Nix packages for 50+ coding agents, daily updates. Useful if we ever want
  agents beyond Claude Code; today the official installer + nix-ld path works
  and is Ring-2 by design.
- **nixd / nil LSP-over-MCP wrappers** — immature; mcp-nixos covers the
  lookup need, and `nix flake check`/dry-run builds cover evaluation truth.
- **Generic community "nix-mcp-server" variants** — less mature duplicates of
  mcp-nixos.
- **AIOS, "agentic Linux" projects** — research-grade LLM-in-the-kernel
  work; conceptually interesting, nothing production-usable. claudeos's
  lanes-on-systemd model is the pragmatic version of the same idea.

## Claude Code ecosystem (skills, plugins)

- **SKILL.md is now an open standard** adopted by 30+ tools
  ([agentskills.io](https://agentskills.io/specification)). Our repo-tracked
  skills are already in the right format; they'd port to other harnesses.
- Marketplaces (claudemarketplaces.com, LobeHub, mcpservers.org) list 400+
  plugins / ~3K skills; **nothing NixOS-specific worth adopting** beyond
  mcp-nixos. The pattern that wins for claudeos is bespoke, repo-tracked
  skills that encode *this system's* invariants (as `/deploy`, `/add-module`,
  `/qml-dial-in` already do).

## Anthropic agentic best practices vs claudeos

From "Writing effective tools for agents", "Effective harnesses for
long-running agents", and the Agent SDK docs (2025–2026):

| Practice | claudeos status |
|----------|-----------------|
| Consolidate tools; few multi-purpose > many narrow | mcp-nixos v2.4 does this (17→2); system-health at 11 small tools is acceptable for bash-cheap diagnostics |
| Tool descriptions are the highest-ROI surface | Applied to the three new validation tools (they encode when/where they work) |
| Mechanical gates over advisory rules | Already core doctrine (rung-2 window, protected paths, VM gate) |
| Progress files + git history for long-running work | Generation labels + git + docs/plans/ serve this |
| Hooks as deterministic lifecycle checkpoints | SessionStart/PostToolUse/PreToolUse in use; `PreCompact` exists but no claudeos use case yet |
| Compact proactively; structured memory stores | Harness-level; auto-memory + CLAUDE.md already in place |
| MCP spec 2026-07-28: stateless core, Tasks extension | No action — our servers are local stdio; revisit only if a server goes remote/HTTP |

## Novel integration ideas — triage

**Built now:** runtime-validation MCP tools (see above). Chosen because it
converts a documented-but-manual safety workflow into something every agent
(including self-heal) can execute and because verification exposed that the
server hosting it was broken anyway.

**Backlogged:** nix-sandbox-mcp evaluation, cross-machine lane (transporter testbed
results gate gti's autoApply), predictive maintenance (weekly "what keeps
breaking" pattern pass over diary + heal-PR history).

**Considered, not pursued:** on-device inference fallback (violates cost
doctrine simplicity; no offline failure mode has bitten yet), MCP Apps
server-rendered UIs (morning desk's file-artifact approach is simpler and
DE-agnostic), voice agents (no current need).

## Lessons from this survey's own verification

Worth recording because they're the survey's most transferable findings:

1. **Registration is not integration.** Two MCP servers were documented in
   CAPABILITIES.md, seeded by Nix, and never once connected — `claude mcp
   list` is the ground truth, not the config file. Any future MCP addition
   must include a "shows Connected in `claude mcp list`" verification step.
2. **Ring-2 seeds can silently target dead paths.** The seed wrote a file
   Claude Code never reads (`~/.claude/.mcp.json`); project-scope `.mcp.json`
   in the repo is both the correct path *and* better doctrine (tracked,
   reviewed, Ring 1).
3. **Transport specs matter for hand-rolled servers.** MCP stdio is
   newline-delimited JSON-RPC; LSP-style Content-Length framing fails
   silently (server just never answers).
