# hyprlock crash + greeter measurement — handoff to a local session

*2026-08-15. Written by the remote (web) session that opened PR #98, for the
local Claude Code session picking it up. The remote container has **no `nix`,
no journal, and no machine access** — every open question below is blocked on
exactly that. A local session closes all of them in minutes. Branch:
`claude/qmlgreet-greeter-alternative-bf3pex` (PR #98, draft).*

## Opening prompt (paste this to start the local session)

> Read `docs/PHILOSOPHY.md`, `docs/plans/2026-08-15-quickshell-greeter-plan.md`,
> and this file first. Two independent jobs, in priority order.
>
> **Job A — diagnose a live hyprlock crash.** The lock screen died and dropped
> to Hyprland's "Oopsie daisy" crashed-lockscreen fallback (photo taken
> 2026-08-15, host unconfirmed — establish which one). Nothing has been deployed
> from PR #98; it is a docs-only branch that was never merged, so this is
> pre-existing. There is a specific hypothesis to test in section 2 below —
> **test it, don't assume it.** If the journal says something else, follow the
> journal.
>
> **Job B — phase 0 of the greeter plan.** Measure regreet startup so we know
> whether the Quickshell greeter proposal is even aimed at the right problem.
> One command, section 3.
>
> Do **not** start phase 1 (the `lib/quickshell-theme.nix` extraction) until Job
> A has a root cause. If A and B share the wallpaper root cause, that changes
> what phase 1 should be.

---

## 1. What is already established (don't re-derive)

**PR #98 did not cause this.** Verified three ways: the branch's single commit
touches one file (`docs/plans/2026-08-15-quickshell-greeter-plan.md`, 188
insertions, zero `.nix`); `git branch --contains` shows it only on the feature
branch, not `main`; and `modules/common/auto-update.nix:65` pulls the
checked-out branch, which is `main`. Nothing was deployed.

**The greeter and the lock screen are different surfaces.** hyprlock runs
*inside* the Hyprland session. greetd/regreet runs *before* any session exists.
The PR #98 plan touches only the latter and would not have fixed this.

**A different lock-adjacent freeze was already solved — don't rediscover it.**
The "greetd locks up if you don't log in within a couple minutes" symptom was
Intel Panel Self Refresh freezing a static eDP panel, fixed fleet-wide with
`i915.enable_psr=0` (`modules/common/boot.nix:30-42`). That is a *freeze*, not
a *crash*, and the fallback screen in the photo means a process actually died.
Different failure. Do not attribute this to PSR without evidence.

**Nothing in `docs/known-issues.md` mentions hyprlock.** This is unlogged; add
an entry when you have the root cause.

---

## 2. Job A — the hyprlock crash

### Config as it stands (verified by reading the repo)

| Fact | Location |
|---|---|
| `programs.hyprlock.enable = true;` — **no `settings` block at all** | `home/hyprland.nix:558` |
| Idle→lock at 300s, dpms off at 600s, suspend-on-battery at 1200s | `home/hyprland.nix:573-587` |
| `lock_cmd = "pidof hyprlock \|\| hyprlock"` | `home/hyprland.nix:569` |
| Manual lock bound to `$mod, L` | `home/hyprland.nix:450` |

Because there is no `settings` block, hyprlock's entire appearance comes from
**Stylix's auto-enabled hyprlock target**.

### The hypothesis to test

Stylix points hyprlock's background at the Stylix image — `assets/dune.jpg`,
which `modules/desktop/theme.nix:146-157` documents as **upscaled to 3840²**.
That is ~14.7 M pixels to JPEG-decode and texture-upload on a 2017 Kaby Lake
iGPU, every time the 5-minute idle timer fires.

**This is unverified in two places, and both are cheap to check locally:**

1. I could not eval the generated `hyprlock.conf` (no `nix` in the remote
   container), so I have **not confirmed** Stylix actually sets that background
   path. Check it directly:
   ```
   cat ~/.config/hypr/hyprlock.conf
   ```
2. I could not measure the image (no imagemagick in the container) — the 3840²
   figure comes from a *code comment*, not from the file. Confirm:
   ```
   identify assets/dune.jpg
   ```

If either check comes back different, **the hypothesis is dead** — say so
plainly and follow the journal instead.

### Diagnostics

```
journalctl --user -b -1 -u hyprlock --no-pager
coredumpctl list hyprlock
coredumpctl info hyprlock          # if a dump exists
journalctl --user -b -1 --no-pager | grep -i -E "hyprlock|lock-session|hypridle"
```

Establish first: **which host**, and whether the crash is **reproducible**
(`hyprlock` from a terminal, or wait out the 300s idle) or a one-off.

### If it is the wallpaper

The fix is a pre-scaled background asset, not a config workaround — and it would
help the greeter too (section 3). Do **not** paper over it by disabling the
Stylix hyprlock target; that loses the theming.

### If it is not

Follow the evidence. Worth knowing that hyprlock has no respawn safety here — if
it dies you get the fallback screen, which is at least recoverable
(`hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'` from another tty)
and does not lose session state.

---

## 3. Job B — phase 0 of the greeter plan

One measurement, to confirm or kill the claim that regreet is slow because it
decodes the same 3840² master at boot:

```
systemd-analyze blame | grep -i greetd
journalctl -b -u greetd --no-pager
```

Record the number in PR #98. If greeter startup is unremarkable, the "slow"
half of the original complaint is **regreet's appearance, not its speed**, and
the plan's phase 0 should be marked resolved-negative rather than quietly
dropped.

If Jobs A and B *share* the wallpaper root cause, that is the single highest-
value fix available and it should ship before any greeter rewrite — say so and
re-scope PR #98 accordingly.

---

## 4. Guardrails

- **`nixos-rebuild switch` on the host Claude is running on can kill the
  session.** `dry-activate` first; commit and push before switching. (Repo
  memory: "switch on host kills session".)
- **Validate compositor config against the running binary** — `nix build` only
  checks Nix eval. `hyprctl configerrors` empty after reload; `qs -p <copy>`
  loads clean. See CLAUDE.md, "Compositor config isn't validated by the build".
- **Never hardcode hex.** Any color change goes through the Stylix base16
  palette. See `.claude/rules/quickshell-qml.md`.
- **Query the `nixos` MCP server before writing any option name** — it was
  unavailable in the remote container, which is precisely why several claims
  above are marked unverified. You have it; use it.

## 5. What "done" looks like

- [ ] Root cause for the hyprlock crash, with journal/coredump evidence
- [ ] `docs/known-issues.md` entry added (dated, with the evidence and the
      verdict — matching the existing entry style)
- [ ] Fix pushed, or an explicit "not reproducible, monitoring" note if it was
      a one-off
- [ ] Phase 0 number recorded in PR #98, hypothesis confirmed or killed
- [ ] A call on whether PR #98's phasing still makes sense given what you found
