# Next-Session Prompts

Ready-to-paste prompts for future Claude Code sessions, written 2026-06-12 with
full session context. Each is self-contained: paste it as the opening message
of a fresh session in `~/.config/claudeos` (or wherever the repo lives).
Every prompt assumes the agent will read `docs/PHILOSOPHY.md` first — hold it
to that.

**Status pass 2026-07-07:** #1 DONE (shipped 2026-06; note its gdm.service
assertion was wrong from day one — GDM runs as display-manager.service — so
the gate silently blocked every update until heal PR #29 fixed it; the
breadcrumb telemetry added the same day exists so that failure class can't
be silent again). #8's claudeos-side ask (appindicator) DONE. #7 partially
seeded (telegram plugin enabled + allowlisted; the long-lived channel session
is not built). #2 (timewarp), #3 (self-merging heal PRs), #4 (morning desk
phase 2), #5 (Hyprland specialisation — dormant by choice), #6 (below flight
recorder) remain open backlog.

**Status pass 2026-07-12 (Fable's last day):** #5 SUPERSEDED beyond its
ambitions — Hyprland didn't return as a specialisation, it became THE desktop
and GNOME was deleted entirely (docs/plans/2026-07-11-gnome-ripout-plan.md,
all three phases complete). #4's attention hooks must use Hyprland-world
signals now (hypridle/`loginctl show-session` for idle, `hyprctl
activewindow -j` for window class — the GNOME DBus paths in the prompt are
gone). #8's claudeos-side tray note: the Quickshell bar hosts the tray
(StatusNotifier), not a GNOME extension. New prompts #10–#12 below were
written by Fable with full rip-out context for Opus execution — trust their
reasoning; verify their facts against the tree before acting. #13–#15 were
added the same day by the MCP-survey session
(docs/research/2026-07-12-claude-integration-survey.md).

---

## 1. The OS that updates itself — VM smoke-test gate — ✅ DONE (2026-06; gate fixed 2026-07-07, PR #29)

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

## 9. Jasper — the personal-companion lane (RESOLVED 2026-07-11)

The 2026-07-08 sketch here proposed *reviving the Rust daemon* (persistent
session, tray, two-repo workflow). That was superseded on 2026-07-11: reviving
the daemon is the "daemon trap" (second brain, separate auth/memory/voice) the
PHILOSOPHY now forbids. **The division of labor still holds — ClaudeOS is the
system's agent; Jasper is Tom's** — but Jasper becomes a *lane*, not a process.
See docs/PHILOSOPHY.md "On Jasper specifically" for the canonical statement.

> Direction: dumb collectors (gcalcli, weather, routes — Jasper's existing sops
> keys) → one `claude -p` call carrying Jasper's persona + ownership-aware,
> one-insight prompt → the Quickshell bar as its face. The Rust daemon and its
> waybar/GNOME/COSMIC/Noctalia frontends are retired; the flake input is
> dropped. Implemented as a ClaudeOS lane in modules/apps/jasper.nix, modeled
> on morning-desk.nix and built on lib/claude-script.nix.
>
> Still-relevant context carried forward:
> - Jasper holds the personal-world credentials (sops: Google
>   weather/routes/calendar OAuth, home address). Deduplicate toward these
>   keys — morning-desk currently uses wttr.in and its own gcalcli bootstrap.
> - Cost: the lane rides the Claude subscription via `claude -p` — NO
>   dedicated ANTHROPIC_API_KEY (the old daemon was the last key consumer).
> - HISTORY: the retired daemon's unit once pulled graphical-session.target
>   active in GDM greeter sessions and killed the greeter in a boot loop
>   (comments in jasper.nix + hosts/transporter/default.nix). Retiring the
>   daemon removes that entire failure class — a lane's timer never touches
>   graphical-session.target.
> - Home Assistant reach and a persistent conversational surface (Telegram,
>   prompt #7) remain open future directions, but layer onto the lane — they
>   are not reasons to stand a daemon back up.

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

## 10. Hyprland burn-in — the week's watchlist (written 2026-07-12)

> Read docs/plans/2026-07-11-gnome-ripout-plan.md (Phase 2) and
> modules/desktop/hyprland.nix + home/hyprland.nix — their comments carry
> the WHY for every mechanism below. This prompt is the judge's handbook
> for the burn-in week on transporter. For each item: how to check, and the
> fix-shape if it fails. Do NOT redesign anything that fails — the
> architecture is decided; failures here are wiring bugs.
>
> - SESSION ENTRY (the known trap): every regreet login must use
>   "Hyprland (UWSM)". Symptom of the plain entry: no wallpaper/idle-lock/
>   night light. Diagnostic FIRST: `systemctl --user is-active
>   graphical-session.target`. Rescue: `systemctl --user start hyprpaper
>   hypridle gammastep`. (Memory: uwsm-target-first-diagnostic.)
> - SUSPEND ON BATTERY: unplug, leave idle 20+ min → suspends. The policy
>   script is suspendOnBattery in home/hyprland.nix (hypridle listener,
>   timeout 1200). If it fires on AC or never fires, debug the
>   /sys/class/power_supply/*/online loop — Dell adapters expose `online`;
>   log the loop's reads before changing logic.
> - AC STAYS AWAKE: overnight on AC, auto-update/diary/morning desk must
>   run. If the machine slept: something ELSE suspended it (logind lid?
>   check `journalctl -b -u systemd-logind`), not hypridle — it has no
>   unconditional suspend listener.
> - NIGHT LIGHT: screen warms after sunset (gammastep, geoclue2 provider).
>   If not: `journalctl --user -u gammastep`; geoclue needs a WiFi fix —
>   if geoclue can't locate, the accepted fallback is provider "manual" +
>   lat/long in home/hyprland.nix services.gammastep (Detroit-ish; ask Tom).
> - CAFFEINE: Super+I → mug in bar (accent); wait 6 min → NO lock. Agent
>   run (touch $XDG_RUNTIME_DIR/claudeos-agent) → muted mug, also no lock.
>   Mechanism: Caffeine.qml (state) + IdleInhibitor in Bar.qml (protocol,
>   needs the bar window). If lock fires anyway, check Hyprland honors
>   idle-inhibit from layer-shell surfaces before touching the QML.
> - KEYRING ROUNDTRIP: reboot → Chrome/Claude Desktop logins persist, no
>   unlock prompt. Mechanism: greetd PAM (enableGnomeKeyring) unlocks the
>   login collection. Check: `busctl --user get-property
>   org.freedesktop.secrets /org/freedesktop/secrets/collection/login
>   org.freedesktop.Secret.Collection Locked` → `b false`.
> - SCREENSHARE: a real Meet/Zoom call → picker appears (xdg-desktop-
>   portal-hyprland). FileChooser in Claude Desktop → GTK dialog (gtk
>   portal). If either missing, check the THREE portal units are active
>   and remember the HM portal-var shadowing memory.
> - GHOSTTY IN NAUTILUS: right-click in Files → "Open in Ghostty".
>   Chain: nautilus-python loader (NAUTILUS_4_EXTENSION_DIR) + ghostty.py
>   via XDG_DATA_DIRS — both verified resolvable 2026-07-12; this checks
>   the runtime load actually happens.
> - Anything that fails and gets fixed: append the fact to
>   docs/known-issues.md or the relevant module comment, same commit.

## 11. gti deploy runbook (written 2026-07-12)

> gti (XPS 13 9370, HiDPI 13") is already flipped to
> `claude-os.hyprland.enable = true` in hosts/gti/default.nix — there is no
> architecture work left, only deployment. Follow INSTALL.md for the
> (re)install; this prompt adds only the Hyprland-specific deltas:
>
> 1. First login at regreet: pick "Hyprland (UWSM)" (see prompt #10's trap).
> 2. HiDPI: transporter runs scale 1.5 on 1080p; gti's 3200×1800 panel
>    wants `monitor = eDP-1, preferred, auto, 2` or 1.6 — set it as a HOST
>    override (hosts/gti or a host-conditional in home/hyprland.nix),
>    NOT a shared default. Verify fractional-scale text sharpness in
>    Ghostty and Chrome (XWayland apps may blur at fractional scales —
>    check `hyprctl clients` for xwayland flags before blaming Hyprland).
> 3. Keyboard: gti has the same Colemak-everywhere expectation; it comes
>    from Hyprland input config + pam_env greeter vars automatically.
> 4. Run prompt #10's checklist end-to-end on gti before calling it done —
>    especially suspend/lid (different EC than the Latitude) and the
>    battery widget (different battery names in sysfs are already handled
>    by the wildcard loop, but verify).
> 5. Cross-machine: after deploy, `git pull` on transporter so both track
>    the same HEAD (CLAUDE.md workflow step 8).

## 12. Deferred desktop projects — context for whoever picks them up

> Three intentional deferrals from the rip-out, each with its trap
> documented. Read the referenced sources before starting any of them.
>
> (a) BESPOKE QML GREETER (the fun one): regreet is deliberately "boring
> glue"; the aspiration is a login screen in the bar's design language.
> Two roads: SDDM-Wayland themes are QML (mature ecosystem; but NixOS
> default greeter-compositor for it pulls Weston, and Stylix has no SDDM
> target — manual base16 wiring), or watch greetd-world QML greeters
> mature. Decision context: docs/plans/2026-07-11-gnome-ripout-plan.md
> "Decisions (locked)" table + the greetd-vs-SDDM rationale paragraph.
> This is a taste project — do it WITH Tom iterating visually, not solo.
>
> (b) HIDE REGREET'S PLAIN "Hyprland" ENTRY: the footgun behind prompt
> #10's first item. The correct-looking fix (filter
> services.displayManager.sessionPackages) is blocked: the entry comes
> from programs.hyprland's own `sessionPackages = [ cfg.package ]`, and
> replacing cfg.package breaks lib.getExe in security.wrappers.Hyprland
> (verified in nixpkgs source 2026-07-12). Workable angles: an upstream
> nixpkgs option to suppress the non-UWSM session; or a low-tech
> systemd tmpfiles/activation snippet that rewrites the desktops-dir copy
> with Hidden=true IF regreet honors it (verify against ReGreet source
> first). Only worth doing if the trap bites again despite regreet's
> last-session memory.
>
> (c) oo7-daemon AS gnome-keyring SUCCESSOR: same D-Bus API
> (org.freedesktop.secrets), reads the same keyring format, Rust. Blocked
> 2026-07-12: locked nixpkgs ships only the oo7 CLI (0.6.0), no daemon
> package, and its PAM-unlock story is younger than pam_gnome_keyring's.
> Re-check when `nix eval nixpkgs#oo7-daemon` resolves; trial on
> transporter; the swap is invisible to apps (interface stays, greetd PAM
> line changes). Context: plan doc "Deferred / future".

## 13. nix-sandbox-mcp — sandboxed execution for agent lanes (written 2026-07-12)

> Read docs/PHILOSOPHY.md (constitution) and
> docs/research/2026-07-12-claude-integration-survey.md §nix-sandbox-mcp.
> Evaluate SecBear/nix-sandbox-mcp (bubblewrap + Linux namespaces, flake-
> declared environments, single `run` tool) as a third MCP server in the
> repo's .mcp.json. The draw: autonomous lanes (self-heal, auto-update)
> could test commands and scripts in an isolated environment instead of on
> the host — mechanical safety, the constitution's preferred kind. Assess
> maturity honestly (it was early-stage as of 2026-07); if it's not ready,
> prototype the same idea as a ~50-line bash MCP tool wrapping
> `bwrap`/`nix shell`. Report findings in docs/ either way.

## 14. Cross-machine lane — transporter results gate gti (written 2026-07-12)

> Read docs/PHILOSOPHY.md (earned autonomy) and modules/common/auto-update.nix.
> Today gti and transporter run the same repo but decide independently. Build
> the smallest useful coordination: transporter (testbed) runs the weekly
> auto-update FIRST; only after its VM gate + a real switch + N hours of zero
> failed units does gti's lane consider the same flake.lock safe to apply.
> Use the git repo itself as the coordination channel (e.g. a
> `tested/<lockfile-hash>` tag or a small state file committed by the
> testbed lane) — no new services, no network listener. The fallback when
> transporter is asleep for a week: gti proceeds on its own gates, as today.
> Document the ladder change in PHILOSOPHY.md.

## 15. Predictive maintenance — "what keeps breaking" weekly pass (written 2026-07-12)

> Read docs/PHILOSOPHY.md (proactivity: prepare, don't inform),
> modules/apps/claude-monitor/default.nix (journal diary, tier 4), and
> backlog #6 (below/BPF flight recorder — build it first or fold it in).
> The monitoring stack is reactive; add the pattern layer: a weekly lane
> (sonnet, one call) that reads the last ~30 days of journal-diary findings
> + docs/known-issues.md + heal-PR history (gh pr list, heal/* branches)
> and answers: what failed more than once, what's trending worse, which
> heal fixes were band-aids. Output: one section in the morning desk +
> (rung-appropriate) a draft PR or docs/known-issues.md update for the top
> recurring item. Strictly bounded context (<200 lines of evidence per
> pattern); no new daemons — a timer, a collector, one model call.
