# The ClaudeOS Philosophy

*Last substantially revised 2026-06-12, capturing the session in which most of
these conclusions were reached. This document is the **why** of ClaudeOS. If
you are a future Claude session (or a future Tom) making a design decision,
read this first — the goal is that you reach the same conclusions we did, or
knowingly improve on them.*

---

## What ClaudeOS is

ClaudeOS is a NixOS configuration optimized for one person's life, with Claude
woven into the operating system — not as a chatbot in a window, but as the
system's maintainer, narrator, and (increasingly) its hands. It is also,
deliberately, a vehicle for experimentation: its owner runs it *because*
trying bleeding-edge plumbing is the fun part.

## The founding insight

**NixOS is the only operating system where the entire system state is one git
repository. Therefore "the OS maintains itself" reduces to "an agent edits a
repo and opens a PR."**

On every other OS, a fix is imperative surgery on live state. Here, a fix is
always *text* — reviewable, revertible, attributable. This single property is
why an AI-maintained OS is tractable at all, and it is the root of almost
every design below: the self-heal agent that files fix PRs when units fail,
the hooks that make untested commits impossible, the boot menu that reads
like a changelog. When evaluating any new idea, ask: *does this exploit the
system-is-a-repo property, or fight it?*

## Why this exists (and why it failed once)

ClaudeOS was abandoned for Ubuntu in March 2026. The reasons are data, not
embarrassment:

1. **Integration pain** — file pickers, drag-and-drop, the Chrome extension,
   the VSCode extension all worked worse than on Ubuntu. Root causes: a niche
   compositor (Niri) and FHS assumptions in fast-moving proprietary tools.
2. **Declarative friction** — VSCode extensions and Claude/MCP configs were
   force-managed by Nix, so every experiment meant edit-nix-then-rebuild.
   The repo literally accumulated activation-script hacks fighting
   home-manager.
3. **The upgrade treadmill** — hand-bumping versions and hashes for
   fast-moving apps (the Claude desktop repack especially) was a sysadmin
   time sink.

What brought it back: a model capable enough to *be* the maintainer. The
economics of running an experimental OS change when the toil falls on Claude
instead of the owner. The first audit of this return found an idle-lock that
had silently never worked, a 12-weeks-dead auto-updater, and an unbounded
snapshot leak — the previous generation of tooling built things; this
generation can also *keep* them working.

## The two-ring rule

**The declarative model stops at the fast-moving Claude-ecosystem boundary.**

- **Ring 1 (declarative):** boot, hardware, services, shell, theming,
  security posture — Nix owns it, the repo is truth.
- **Ring 2 (mutable):** VSCode extensions (Marketplace-managed), Claude Code
  settings and MCP configs (seeded once by Nix, then owned by the live
  tools), the Claude binaries themselves (self-updating by design).

The failure mode this prevents: making Nix own a layer that hates being
owned. Experimentation in ring 2 is a file edit; reproducibility in ring 1 is
a rebuild. Never declare ring-2 state in Nix "for completeness" — that
instinct is how the March failure started. The same pattern applies at every
scale (e.g. coreutils: Rust uutils on the interactive PATH, GNU for system
scripts).

## The proactivity doctrine

This is the philosophical core, reached after several wrong drafts. The wrong
drafts kept producing *widgets* — pipelines ending in a string on a status
bar. The realization:

**Jasper's question was "what should Tom know right now?" The operating-system
question is "what state should Tom's computer be in right now — and what work
should it have already done?"**

Information delivery is the *mouth*, and the mouth is the smallest organ. A
great assistant doesn't follow you around reading bullet points; it lays
things out before you ask, does the boring prelude while you're away, and
keeps half-finished things from dying. Hence:

1. **Prepare, don't just inform.** The output of proactivity is environments
   and artifacts (a prepared dashboard, a fetched attachment, a drafted
   reply), not notifications about things you could prepare yourself.
2. **Absence is the resource.** The laptop is idle ~20 hours a day.
   Proactivity mostly isn't real-time; it's overnight work product waiting at
   first login (Morning Desk, journal diary, weekly update — all run while
   nobody watches).
3. **One thing, never a feed.** Inherited from Jasper and kept as doctrine:
   surface the single most important thing, ranked hierarchy below it,
   system minutiae smallest. Interruptions must earn their moment.
4. **Autonomy is earned, not configured.** Every autonomous lane starts at
   the bottom rung: propose (a PR, a draft, a file) and let the human act.
   Graduation to just-do-it happens per-lane, with track record. Artifacts
   must be reversible — a branch, a draft, a discardable file; never a sent
   email, never a push to main. *First graduated lane (2026-06): the weekly
   flake update now applies itself (`autoApply = true`). It bought the rung
   with a mechanical gate rather than trust alone — the freshly built
   generation must boot green in a throwaway QEMU VM (multi-user reached,
   zero failed units, GDM up) before commit, push, or switch; a red run
   reverts flake.lock and hands the VM journal to the self-heal agent. The
   general rule this sets: a lane may also graduate by adding a machine
   check that catches the failure class a human review was catching —
   exploit the system-is-a-repo property (the entire next OS state is a
   derivation you can boot before betting the laptop on it). And the result
   stays reversible the NixOS way: the previous generation is one reboot
   away. Second graduated lane (2026-07): low-risk self-heal PRs now merge
   themselves — see "The rung-2 window" under the constitution. It bought its
   rung the same way, and the shape generalizes: **graduation is a narrow
   window plus a machine check, never a broad grant of trust.***
5. **The computer's unique knowledge is attention and activity** — what's
   focused, what's half-done, whether you're even there. Web services know
   your calendar; only the OS knows your *state*. Future capabilities should
   mine this (structured state only — windows, tabs, cwd, git status — never
   content surveillance).

### On Jasper specifically

Jasper (the Rust daemon) is the philosophy's reference implementation from
the pre-agentic era, and it got the doctrine right: significance-gated
thinking (only call the model when the world changed), single-insight
output, ownership awareness ("Christen has soccer," never "you have soccer").
**We deliberately did not revive the daemon.** It hand-rolls what Claude Code
now provides natively (tools, sessions, memory, rate limiting), and reviving
it would create a second brain with separate auth, memory, and voice. The
rule generalizes: **take the thinking, not the daemon.** Port doctrines into
prompts; let collectors be dumb scripts; let Claude Code be the only brain.

## The constitution

Autonomous agents editing the OS are made safe by *mechanical* rules, not
advisory ones:

- Repo-tracked Claude Code hooks enforce CLAUDE.md: every `.nix` edit is
  auto-formatted and parse-checked with errors fed back to the agent; a
  `git commit` with staged `.nix` changes is **denied** unless the flake
  evaluates. The constitution lives in git, so every change to what agents
  may do is a reviewable diff.
- Agents work on branches (`heal/*`) and open PRs. **A PR merges itself only
  inside the rung-2 window below; everything else waits for a human.**
- Identity note: agents run as the user (a separate "agent user" fights
  Claude Code's per-user OAuth model — evaluated and rejected). Scoping comes
  from `--allowedTools` allowlists, systemd sandboxing where user units
  support it, cooldowns, and loop-prevention (never attach self-heal to
  itself).

### The rung-2 window (self-merging heal PRs)

*Second graduated lane, 2026-07-09. Implemented in
`.github/workflows/heal-automerge.yml`.* A `heal/*` PR squash-merges itself
when **all** of the following hold — and is held open with a comment
explaining why, the moment any one of them does not:

1. CI green on that exact commit: treefmt/statix/deadnix, a dry-run eval of
   every host, and one real `system.build.toplevel` build.
2. The diff touches **exactly one** `*.nix` file under `modules/` or `home/`.
3. It touches none of `flake.nix`, `flake.lock`, `.sops.yaml`, `secrets/`,
   `.github/`, `.claude/`.
4. Forty changed lines or fewer.
5. A Claude machine-review returns exactly `VERDICT: APPROVE`.
6. No `heal-hold` label. *(Applying it is the human's stop button.)*
7. The PR head is still the commit CI tested.

The window is drawn so that everything inside it is **cheap to be wrong
about**. One module file cannot alter the boot path, the disk layout, the
secrets, the pinned inputs, or the rules governing agents — those are all
either protected paths or beyond a one-file diff. And the blast radius has a
floor NixOS gives us for free: a bad merge is one `git revert` or one reboot
into the previous generation.

Three properties make this a graduation rather than a surrender, and a future
change that breaks any of them un-earns the rung:

- **The gate is a machine check, not a vibe.** Rung 1's approval gate was a
  human reading a small diff. Rung 2 replaces it with the failure classes that
  human was actually catching — build breakage (a real toplevel build), style
  and dead-code drift (statix/deadnix), and "would a reviewer have commented?"
  (a Claude call with a strict `VERDICT:` contract, failing closed on silence,
  on garbled output, and on its own uncertainty). This is the rule item 4 of
  the proactivity doctrine sets: *a lane may graduate by adding a machine check
  that catches the failure class a human review was catching.*
- **The gate cannot be edited by what it gates.** `.github/` is a protected
  path, and `workflow_run` always executes the default branch's copy of the
  workflow. An agent cannot widen its own window — not even by merging a PR
  that widens it.
- **Machine gates never parse prose.** The human-readable review posted by
  `claude-code-review.yml` is written for Tom and is *not* consulted by the
  gate. The gate makes its own call with a one-line output contract. Prose
  written for a person is not a control signal; the day a review template gets
  reworded, merge behaviour must not change.

The honest residual risks, recorded rather than hidden: the diff is untrusted
text fed to the reviewing model, so prompt injection is possible in principle
(mitigated by the one-file/40-line window, the green build, and revertibility,
not eliminated); the branch prefix `heal/*` is the only thing marking a PR as
agent-authored, and a human can push that prefix too — which is acceptable
precisely because the gate judges content, never authorship; and `workflow_run`
hands a write token to a job that checks out PR-authored code, safe only while
that job refuses forks and never *executes* what it checks out.

## Security posture (decided, not pending)

The owner's explicit trade-offs — do not re-litigate these in future audits;
re-open them only if the threat model changes (e.g. the machine stops being
single-user):

- **No full-disk encryption.** Nothing confidential lives locally; boot
  friction isn't worth it.
- **Supply-chain looseness is deliberate.** `curl | bash` for Claude Code,
  unpinned MCP flakes, tag-pinned actions — freshness of Claude tooling
  outranks pinning.
- **Claude autonomy over hardening** — passwordless `manage-units` for wheel,
  `@wheel` in nix trusted-users, `skipDangerousModePermissionPrompt` stay.
  The one carve-out: `manage-unit-files` is excluded (silently installing new
  root services crossed the line).
- What *is* enforced: sudo-rs, boot-editor off, LLMNR off, sops-nix for
  secrets, the constitution above.

## Cost doctrine

- Claude Max subscription ($200/mo) is the default lane for everything:
  headless `claude -p` and agent sessions ride it.
- Up to **$10–20/month API** is acceptable as headroom (reliability lane for
  background units, quality bumps) — the constraint is "no sticker shock,"
  enforced by spend caps, not abstinence.
- haiku for high-frequency paths (slugs, triage), sonnet-class for rare
  agentic work (heal PRs, the daily dashboard). Everything event-driven or
  scheduled; nothing polls an LLM.
- **Nothing may require a frontier-of-frontier model to run.** Design with
  the best model available; run on the standard ones.

## Taste

These are aesthetic commitments that double as engineering bets:

- **Ephemerality is sacred.** The owner's deepest OS preference: software
  leaves no trace. Dev shells, `, foo` (comma), trace-free experimentation —
  protect this property; it is *why NixOS* in one word.
- **Bleeding-edge plumbing on purpose:** PipeWire, Wayland, systemd-boot,
  systemd-initrd, nftables, sched_ext schedulers, the oxidized userland
  (sudo-rs, uutils, fish 4, the Rust CLI ring). Trying new system tech is a
  goal, not a risk to minimize.
- **The system narrates itself.** Generations are named by what changed
  (boot menu as changelog), snapshots carry the same names, the journal
  diary keeps a ledger, every agent leaves an audit trail. A system you can
  read is a system you can trust with autonomy.
- **Desktop environment is a replaceable organ.** GNOME today (chosen
  2026-06: familiarity and first-class app integration beat Niri, which
  "felt like fighting it"). Core capabilities must stay DE-agnostic —
  artifacts are files, openers are URLs, notifications are libnotify.
  Compositor experiments return as specialisations, not rewrites.
- **Testbed before primary.** transporter (the old Latitude) proves risky
  changes — DE pivots, integration claims, agent autonomy — before gti is
  touched.

## How to use this document

When proposing something new, check it against the failure that birthed each
rule: Does it make Nix own a fast-moving layer (March failure)? Does it end
in a widget when it could end in prepared work (the Jasper trap)? Does it
need a second brain (the daemon trap)? Does it grant silent autonomy instead
of earned autonomy? Does it cost per-poll instead of per-event? If it passes
those, it probably belongs here — and if it *changes* one of these
conclusions, update this file in the same PR, because this document is part
of ring 1: the philosophy is declarative too.
