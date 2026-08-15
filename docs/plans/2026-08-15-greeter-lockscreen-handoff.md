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
> **Job A — diagnose a live hyprlock crash on `gti`.** The lock screen died and
> dropped to Hyprland's "Oopsie daisy" crashed-lockscreen fallback (2026-08-15).
> Nothing has been deployed from PR #98; it is a docs-only branch that was never
> merged, so this is pre-existing. There is a specific hypothesis to test in
> section 2 below — **test it, don't assume it.** If the journal says something
> else, follow the journal.
>
> Note that this has **two separable defects**, and the second is arguably more
> urgent: hyprlock crashed, *and* Hyprland's documented recovery command doesn't
> work on this build, which strands you at a TTY. Section 2 has a verified
> working recovery ladder. Fix the recoverability even if the crash turns out to
> be a one-off.
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

Follow the evidence.

### Recovery — the documented escape hatch does NOT work on this build

**Verified on `gti`, 2026-08-15.** Hyprland's crashed-lockscreen fallback screen
tells you to run `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`.
On this build that returns:

```
eval is only supported with the lua config manager
```

We do not enable Hyprland's lua config manager, so **the on-screen instructions
are dead** — Hyprland ships advice its own default configuration cannot follow.
This is independent of whatever crashes hyprlock, and it is the difference
between a five-second recovery and being stranded at a TTY on the primary host.

Working ladder instead, least destructive first, all from a TTY (ctrl+alt+F3):

```
# 1. Re-lock properly: a fresh lock client takes over the crashed lock,
#    then unlocks normally. Preserves the session and open work.
killall -9 hyprlock
eval "$(systemctl --user show-environment | grep -E '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE|XDG_RUNTIME_DIR)=' | sed 's/^/export /')"
hyprctl monitors                      # sanity check: should print the display
hyprlock                              # then ctrl+alt+F1 and type the password

# 2. If hyprlock won't start, its failure IS the diagnostic — capture it:
hyprlock 2>&1 | tee /tmp/hyprlock-fail.txt

# 3. Clean logout (loses unsaved work, returns to greeter):
hyprctl dispatch exit

# 4. Last resort:
sudo systemctl restart greetd
```

UWSM exports those three variables into the systemd user environment, which is
why step 1 works without digging through `/proc`.

**This deserves its own fix and its own `known-issues.md` entry, separate from
the crash root cause.** Options worth weighing: enabling the lua config manager
purely to restore the escape hatch, or a keybind/script that runs the step-1
ladder directly. Do not let it get buried under the crash investigation — a
recoverable lock failure is a different severity from an unrecoverable one.

### Host note

The observed crash is on **`gti`** — the primary daily driver, not the
`transporter` testbed. The greeter plan's "prove on transporter first" phasing
does not help here, and any hyprlock fix needs to land on `gti` to be worth
anything. Weigh that against the usual don't-experiment-on-the-daily-driver
caution.

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
- [ ] **Lock-screen recovery made to actually work on `gti`** — the `eval`
      escape hatch is dead here (section 2). This is a separate deliverable from
      the crash root cause and should not be closed by fixing the crash alone.
- [ ] `docs/known-issues.md` entries added — **two of them**, one for the crash
      and one for the broken escape hatch (dated, with evidence and verdict,
      matching the existing entry style)
- [ ] Fix pushed, or an explicit "not reproducible, monitoring" note if it was
      a one-off
- [ ] Phase 0 number recorded in PR #98, hypothesis confirmed or killed
- [ ] A call on whether PR #98's phasing still makes sense given what you found
