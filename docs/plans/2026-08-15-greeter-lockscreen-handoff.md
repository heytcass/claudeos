# hyprlock crash + greeter measurement — handoff to a local session

> **CLOSED 2026-08-15. Both jobs done; three of this document's hypotheses were
> wrong.** Read this box before anything below it — the body is preserved as the
> reasoning-at-the-time, not as current fact.
>
> **Job A root cause — it was neither the wallpaper nor a hyprlock defect.**
> hyprlock is forked by hypridle and lives in `hypridle.service`'s cgroup
> (journald proves it by tagging hyprlock's own stdout as `hypridle[PID]`,
> since it attributes by cgroup). hypridle runs `KillMode=control-group`,
> `KillSignal=15`. When home-manager activation logged
> `Stopping units: … hypridle.service …` at 03:41:16, it **SIGTERM'd the
> hyprlock holding the active session lock**. That instance's last line is one
> second earlier and it is the only hyprlock in the journal that never logs
> `Unlocking session`. SIGTERM leaves no core — which is why the coredump hunt
> below finds nothing. The 03:46 relaunch was then **denied, not successful**:
> `onLockFinished called. Seems we got yeeten. Is another lockscreen running?`
> — Hyprland refusing a second `ext-session-lock-v1` because
> `misc:allow_session_lock_restore` defaults false. The denied process lingered,
> satisfying the `pidof hyprlock ||` guard, which short-circuited all seven
> later idle triggers.
>
> **This generalises**, which section 2 did not anticipate: the mechanism is
> cgroup teardown, so a plain home-manager switch with *no version change* would
> wedge the lock identically. Rarity does not come from version skew.
>
> **Dead hypothesis 1 — the 3840² `assets/dune.jpg` decode.** The image really
> is 3840², but hyprlock logs `Resources gathered after 189 milliseconds` on
> every launch across a dozen-plus locks. Not implicated in either job.
>
> **Dead hypothesis 2 — a Hyprland 0.56.2 session-lock regression.** The
> compositor never restarted (`Started Main service` 08-10 17:55:48, `Stopping`
> 08-15 10:51:18), so **0.56.1 was in memory for the entire incident**; 0.56.2
> first executed at the 10:51:48 reboot, after it was over.
>
> **Correction to section 2's framing of the escape hatch.** `.conf` is not "the
> broken path". `eval` and `keyword` are mirror-image gated in
> `src/debug/HyprCtl.cpp` — each format has a working hatch. The real defect is
> that `lockdead.png` is a **static PNG with no source**, so it cannot branch on
> config type; it was rewritten to the Lua wording in hyprwm/Hyprland#14213 and
> therefore misinstructed every `.conf` user. Since the config has migrated to
> Lua (#100), the on-screen advice now works as printed.
>
> **Job B — resolved NEGATIVE.** greetd is ready in ~1 s; `graphical.target` at
> 4.75 s; `systemd-analyze blame` does not list greetd at all. The 30 s to a
> prompt is 18.5 s of Dell UEFI firmware. regreet is not slow.
>
> **Shipped in #99 and #100:** auto-update `switch`→`boot`;
> `misc.allow_session_lock_restore = true`; `security.pam.services.hyprlock`
> (hyprlock had no PAM stack and fell back to `/etc/pam.d/su`, so screen-unlock
> never unlocked the keyring — a real find, but *not* a contributing cause); a
> VM-gate check of the generated Hyprland config; `hypr_config_check` rebuilt on
> the format-agnostic `Hyprland --verify-config`; and the hyprlang→Lua
> migration. Both `docs/known-issues.md` entries are filed.
>
> **Still open:** hardening the mechanism itself — `KillMode=process` on
> hypridle, or not spawning hyprlock as a hypridle child, or an idempotent
> `lock_cmd`. The `pidof hyprlock ||` guard is what turned a recoverable failure
> into an unrecoverable one and remains unchanged.

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

- [x] Root cause for the hyprlock crash, with journal evidence — cgroup
      teardown via hypridle's `KillMode=control-group`. **No coredump exists**,
      because SIGTERM leaves none; hyprlock wedged rather than crashed.
- [x] **Lock-screen recovery made to actually work on `gti`** —
      `misc.allow_session_lock_restore = true` (#99) makes
      `hyprctl dispatch exec hyprlock` re-arm a prompt while keeping the session
      locked. The Lua migration (#100) additionally restores the
      `hyprctl eval 'hl.clear_crashed_lockscreen()'` hatch the fallback screen
      actually prints.
- [x] `docs/known-issues.md` entries added — two, per this list; the
      escape-hatch one is now marked **RESOLVED** by the Lua migration.
- [x] Fix pushed and merged (#99, #100), staged on `gti` via `nixos-rebuild
      boot`. Reproducibility: one-off — `Stopping units: …hypridle…` appears
      exactly once across all 10 retained boots, and `yeeten` exactly once, five
      minutes later. The weekly timer only landed on a locked session because
      Aug 8's 03:00 run fired while the machine was off and `Persistent=true`
      deferred it to a midday boot.
- [x] Phase 0 number recorded — greetd ready in ~1 s, `graphical.target` at
      4.75 s, not listed by `systemd-analyze blame`. **Hypothesis killed.**
- [x] A call on PR #98's phasing: phase 0 resolves negative, so the Quickshell
      greeter is now an appearance-and-footgun argument, not a performance one.
      The plan doc has been updated to say so rather than quietly dropping it.
- [ ] **Not done — the mechanism itself is unhardened.** `switch`→`boot` removes
      the trigger the auto-update lane pulls, but a manual `nixos-rebuild
      switch` on a locked session still kills the lock client. Options:
      `KillMode=process` on hypridle, not spawning hyprlock as a hypridle child,
      or an idempotent `lock_cmd` (the `pidof hyprlock ||` guard is what turned
      a recoverable failure into an unrecoverable one).
