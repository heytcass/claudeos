# Next-Session Prompts

Ready-to-paste prompts for future Claude Code sessions, written 2026-06-12 with
full session context. Each is self-contained: paste it as the opening message
of a fresh session in `~/.config/claudeos` (or wherever the repo lives).
Every prompt assumes the agent will read `docs/PHILOSOPHY.md` first — hold it
to that.

---

## 1. The OS that updates itself — VM smoke-test gate

> Read docs/PHILOSOPHY.md and modules/common/auto-update.nix first. Build the
> VM smoke-test gate that makes fully autonomous weekly updates safe, then
> flip `claude-os.autoUpdate.autoApply` to true.
>
> Requirements: after `nix flake update` and a successful build, boot the
> freshly built generation in a throwaway QEMU VM (`config.system.build.vm`
> with a `virtualisation.vmVariant` that strips hardware-specific config —
> graphics off, memory ~4G, no GPU) and assert: multi-user.target reached,
> `systemctl --failed` empty, and gdm.service active, within a timeout
> (~5 min). Only on a green VM run: commit, push, and `nixos-rebuild switch`.
> On a red run: revert flake.lock, notify with the failing unit list, and
> hand the journal excerpt to the self-heal agent pattern.
> Constraints: /dev/kvm is available on both hosts (verified); the gate must
> degrade gracefully when KVM is absent (skip gate, fall back to build-only
> + no autoApply). Keep it inside auto-update.nix or a small helper module.
> Update docs/PHILOSOPHY.md's autonomy ladder note (this is a lane
> graduating from propose to just-do-it) and docs/MODULES.md. Validate with
> nix flake check for both hosts; do not claim runtime success — add the VM
> gate's first real run to the testbed checklist.

## 2. `timewarp` — named time travel

> Read docs/PHILOSOPHY.md, modules/common/generation-label.nix,
> modules/common/snapshots.nix, and the `rebuild` function in
> home/shell/fish.nix. Build `timewarp`: a fish function (plus any small
> helper script) that completes the time machine.
>
> Behavior: `timewarp` with no args lists named states — generation labels
> (from `nixos-rebuild list-generations` / /nix/var/nix/profiles) joined
> with their snapper pre/post pairs (matched by the shared slug in the
> snapshot description) — newest first, with dates. `timewarp <slug>` rolls
> back BOTH: activates that generation
> (/nix/var/nix/profiles/system-<n>-link/bin/switch-to-configuration switch,
> via sudo) and offers snapper undochange for root and home from the
> matching post-snapshot to now (prompt y/N per config; default N for home).
> `timewarp --boot <slug>` just sets the bootloader default for next boot
> instead of switching live.
> Constraints: never delete anything; print exactly what will run before
> running it; require confirmation. Handle slug-not-found and
> generation-GC'd-but-snapshot-remains gracefully. Update
> docs/TROUBLESHOOTING.md rollback section and CAPABILITIES.md.

## 3. Self-merging heal PRs — autonomy rung two

> Read docs/PHILOSOPHY.md (the constitution + earned-autonomy sections),
> modules/common/self-heal.nix, and .github/workflows/claude-code-review.yml.
> Build the second rung of the trust ladder: low-risk heal PRs merge
> themselves after machine review.
>
> Design: a GitHub Actions workflow that triggers on PRs from `heal/*`
> branches and (a) runs `nix flake check` for both hosts in CI (install Nix
> via the Determinate action, magic-nix-cache for speed), (b) lets the
> existing Claude review workflow post its review, (c) auto-merges ONLY when
> ALL hold: flake check green, Claude review contains no blocking findings,
> the diff touches exactly one module file under modules/ or home/, diff is
> under ~40 changed lines, and it does not touch flake.nix, flake.lock,
> secrets, .sops.yaml, .github/, or .claude/. Anything else stays open for
> human review. Use a labeled escape hatch (`heal-hold` label blocks
> auto-merge). Document the policy in PHILOSOPHY.md's constitution section
> (same PR) and in self-heal.nix comments.
> Be honest about GITHUB_TOKEN permissions and branch-protection
> interactions; if the repo needs settings changes (allow auto-merge), list
> them as manual steps in the PR description.

## 4. Morning Desk phase 2 — attention + Gmail

> Read docs/PHILOSOPHY.md (proactivity doctrine) and
> modules/apps/morning-desk.nix. Two additions, keeping the files-only,
> DE-agnostic core:
>
> (a) GMAIL SOURCE: a collector that surfaces only messages intersecting
> with today (calendar attendees, tracked threads, explicit VIPs from a
> config list) — never an inbox dump. Use gmailctl-style OAuth or extend the
> gcalcli credential flow; secrets via sops
> (jasper_google_client_id/secret already exist for the OAuth app — add the
> gmail.readonly scope).
> (b) ATTENTION GATING for the rest of the day: a tiny context file
> (~/.cache/claudeos/attention.json) updated by cheap hooks — GNOME idle
> state via DBus, active window class via the shell introspection that
> GNOME allows, AC/battery, SSID — and a midday/afternoon desk refresh that
> may ONLY notify (vs silently update the dashboard) when the attention
> file says the user is interruptible. The dashboard page itself gains a
> small "stale by Xh — refresh" affordance.
> Per the philosophy: one thing on top, interruptions earn their moment,
> structured state only (no content surveillance), artifacts not strings.

## 5. Hyprland as a parallel universe (when the itch returns)

> Read docs/PHILOSOPHY.md (DE is a replaceable organ) and
> modules/desktop/gnome.nix. Add a `specialisation.hyprland` to the gti
> config: same system, one delta — Hyprland + a minimal bar (waybar or
> hyprpanel) + the four Claude keybindings ported. It must appear as its own
> systemd-boot entry and be live-switchable via
> /run/current-system/specialisation/hyprland/bin/switch-to-configuration.
> Constraints: zero changes to the GNOME default path; the specialisation
> may not grow shared config — anything both need moves to a common module
> first. Note eval-time and closure-size cost honestly in the PR.

## 6. BPF flight recorder — evidence for the heal agent

> Read docs/PHILOSOPHY.md and modules/common/self-heal.nix. Enable
> services.below (Meta's BPF cgroup history recorder) with modest retention
> (retention.time ~3 days, cgroupFilterOut for noise), and extend the
> claude-heal@ script: when a unit fails, dump the failing unit's cgroup
> timeline for the 10 minutes before failure (`below dump cgroup -b ... -O
> json`) and include a trimmed excerpt in the agent's context. Note: the
> systemd-oomd kill message ID is SD_MESSAGE_UNIT_OOMD_KILL
> (d98961b1...), NOT the kernel OOM one — match both when looking for
> memory-pressure kills. Keep the dump bounded (<200 lines) so agent context
> stays cheap.

## 7. Telegram as a live channel (testbed experiment)

> Read docs/PHILOSOPHY.md (cost doctrine, bidirectional ops) and the
> Telegram plugin docs (~/.claude/plugins/.../telegram/README.md). The
> plugin supports INBOUND routing: messages to the bot reach a session
> launched with `claude --channels plugin:telegram@claude-plugins-official`.
> Experiment: a long-lived systemd user service that keeps such a session
> alive with a tight permission allowlist (read-only system tools +
> docs/known-issues.md edit), so texting the bot from a phone = talking to
> the OS. Evaluate: session longevity, subscription quota burn, what
> happens on suspend/resume, and whether the morning brief + heal
> notifications should migrate from notify-send to this channel. This is an
> experiment — report findings in docs/, don't enable by default.

## 8. Claude Desktop: native-feel overhaul (claude-desktop-linux-flake)

> Work in the heytcass/claude-desktop-linux-flake repo (plus one small
> claudeos PR). Read this prompt fully; the strategy is "curate, don't
> maintain" — stop hand-maintaining patches and make the flake a thin Nix
> layer over the most active community patch set.
>
> CONTEXT (verified 2026-06-12): the flake repacks the macOS DMG
> (downloads.claude.ai/releases/darwin/universal/ — RELEASES.json there
> lists the latest version, ideal for CI). It sits ~8 releases behind
> (1.11847.5 vs 1.12603.1). It defaults to X11 (`GDK_BACKEND=x11`,
> pkgs/claude-desktop.nix:295-304) because Wayland global shortcuts were
> historically broken. PR #90 (dahikino, ~5500 lines) vendors
> aaddrick/claude-desktop-debian's battle-tested patch set + Cowork daemon
> support and is unreviewed. patchy-cnb stubs @ant/claude-native. Open
> issues: #8 (claude:// via xdg-open), #36 (Wayland hotkey), #43 (OAuth /
> claude-cli resolution), #86 (origin validation on newer versions).
>
> DO, in order:
> 1. REVIEW AND LAND #90 (or rebase/cherry-pick it): adopting aaddrick's
>    vendored patches outsources patch maintenance to the most active
>    Linux-desktop project. Verify against latest version; fix-forward.
> 2. AUTO-BUMP CI: weekly GitHub Action — read RELEASES.json, update
>    version+hash, nix build, open a PR. Kills the 8-release lag class
>    permanently (the "flake dance" that drove the owner off NixOS).
> 3. NATIVE-FEEL WRAPPER (the Fable-era fixes — Electron/Chromium now
>    supports these): flip the default to native Wayland with
>    `--ozone-platform-hint=auto` and
>    `--enable-features=UseOzonePlatform,WaylandWindowDecorations,GlobalShortcutsPortal`
>    (the XDG GlobalShortcuts portal makes Ctrl+Alt+Space work natively on
>    GNOME 48+ — verify the exact flag name against the packaged Electron),
>    `GTK_USE_PORTAL=1` for native GNOME file dialogs, add `--class Claude`,
>    keep an X11 fallback env var (invert today's default). Verify
>    claude:// registration end-to-end (issue #8) — desktop file +
>    update-desktop-database + `xdg-open "claude://test"`.
> 4. CLAUDEOS SIDE (one small PR there): GNOME has no tray by default —
>    add gnomeExtensions.appindicator (+ enable via dconf) so the tray
>    patches actually have somewhere to live.
> 5. HONESTY CHECK: after 1-4 the remaining macOS gap is in-app
>    auto-update (correctly Nix's job — covered by CI) and whatever
>    Cowork/computer-use needs real native bindings (patchy-cnb stubs;
>    document, don't fake). Test matrix: launch, login OAuth round-trip,
>    tray, hotkey, file picker, drag-drop, claude:// — on the transporter
>    testbed.
