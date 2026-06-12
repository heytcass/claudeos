# Tool Rethink — Fresh Eyes vs. the Philosophy

*2026-06-12. Four-lens multi-agent review of every incumbent tool choice, scored against docs/PHILOSOPHY.md. Verdicts: keep / switch / trial-on-testbed / drop. Verification was done against the locked nixpkgs and current upstream state.*

**Synthesis:** the stack largely survives fresh scrutiny — fish 4, ghostty, starship, the CLI ring, VSCode (Zed's Claude lag re-verified), Chrome (Claude-in-Chrome is load-bearing), Obsidian (plain-markdown vault = agent substrate), zathura, Stylix, and direnv all stay on the merits. The real findings: two unmaintained tools to replace (nil→nixd, imv→Loupe), three philosophy violations to delete (fail2ban, Plymouth — it costs half the rollback headroom, the macchina spec-sheet MOTD), Electron repacks→PWAs (the March pattern in miniature), the per-shell GitHub token export→scoped wrapper, atuin's half-enabled sync (finish or delete), iwd as NM's wifi backend (testbed), and jujutsu (very much the house taste, but it would silently bypass the commit-gate constitution — testbed only, with a jj-aware gate first).

**Panel conflict, resolved:** shell lens said macchina→fastfetch (maintenance grounds); plumbing lens said drop the fetch entirely (proactivity doctrine: a spec-sheet above the daily brief is a feed, not the one thing). The philosophy-coherent answer is **drop**; the clawd ASCII can live on the morning-desk dashboard if missed.


## Lens: shell-terminal

### ✅ KEEP — Login shell
**Current:** fish 4 (home/shell/fish.nix) with rebuild/approve/today/fix/explain functions  
**Alternative:** n/a (nushell evaluated and rejected)

Fish 4 already IS the oxidized choice — it was rewritten in Rust, so nushell adds no oxidation points, only churn. Verified: nushell is still 0.113.1 (locked flake) with breaking changes every 4 weeks and no 1.0 timeline — Nix-owning its config is precisely the March failure (ring 1 owning a fast-moving layer). The ~200 lines of fish functions in fish.nix (rebuild's snapper+slug+autocommit flow especially) are working Claude-integration plumbing, and Claude Code's Bash tool sidesteps the interactive shell anyway, so nushell's structured data buys nothing for the agent. Survives fresh scrutiny decisively.

*Migration cost:* n/a — moving would mean porting ~200 lines of load-bearing fish functions plus chasing nushell's 4-weekly breaking changes in ring 1

### ✅ KEEP — Terminal emulator
**Current:** ghostty 1.3.1 (home/ghostty.nix)  
**Alternative:** n/a (kitty/wezterm/foot/rio all weaker fits in 2026)

Ghostty is the only GPU terminal with native GTK4/libadwaita integration, which matters now that GNOME is the DE ('first-class app integration beat Niri'). The config already exploits this (gtk-titlebar, Adwaita tab bar, linux-cgroup=always) plus fish shell-integration. Rio is more oxidized (Rust) but its GNOME/libadwaita fit and config maturity still trail; wezterm's release cadence has been slow for years; kitty/foot gain nothing. Plain-text config, Stylix-themed, actively developed at 1.3.1 — passes every tenet.

*Migration cost:* n/a

### ✅ KEEP — Shell history
**Current:** atuin 18.16.1 with sync disabled (home/shell/cli-tools.nix:79-99)  
**Alternative:** n/a — but finish the job: enable sync with key in sops

Atuin earns its keep over plain fish history (SQLite history is queryable by agents — 'the computer's unique knowledge is activity'). But the half-enabled state is cruft: sync_address = "" with a comment describing the three-step enablement is exactly the kind of dormant feature the first audit found rotting (the 12-weeks-dead auto-updater). With two hosts (gti + transporter) sharing one git-synced config, shared history is genuinely useful, and Claude-as-maintainer makes the sops wiring a one-PR job. Use atuin's hosted sync (E2E-encrypted, no new root service — avoids the manage-unit-files line). Either enable it or delete the dead settings; don't leave the TODO in ring 1.

*Migration cost:* Add atuin_key to secrets/secrets.yaml, re-declare it in modules/common/secrets.nix, set key_path + sync_address — one small PR, reversible

### 🔄 SWITCH — System fetch / greeter
**Current:** macchina 6.4.0 (home/macchina.nix, custom clawd ASCII + Stylix theme)  
**Alternative:** fastfetch 2.63.1

Verified: macchina is officially in maintenance mode — the CLI repo's last activity was March 2025, only the libmacchina library still gets updates, while fastfetch ships releases constantly (2.63.1 in the lock). 'Bleeding-edge on purpose' cuts against riding a frozen tool for the first thing every shell shows you; this is the one component in the stack that fails the maintenance test outright. Fastfetch's JSONC config is agent-friendly and the clawd ASCII + base16 key colors port 1:1. Claude-as-maintainer makes this a 30-minute migration, which is exactly when low switching cost should be spent.

*Migration cost:* Rewrite macchina.nix as fastfetch.nix (JSONC config: same 7 fields, clawd logo file, scheme.base09/base03/base08 colors), swap the macchina call in fish interactiveShellInit

### ✅ KEEP — Prompt
**Current:** starship 1.25.1 (home/shell/starship.nix, custom generation/degraded/claude modules + transient prompt)  
**Alternative:** n/a

Just rebuilt, and the rebuild is philosophy made visible: the named-generation module, the failed-units pip whose absence is the feature, and the ✳ Claude-session marker are 'the system narrates itself' rendered in the prompt — oh-my-posh or a custom prompt would reproduce this with more code and less Stylix integration. Starship is Rust, active, TOML-configured: agent-friendly on every axis. One watch item, not a verdict-changer: custom.degraded forks systemctl twice on every prompt render (its 'when' clause), ~10-20ms; if prompt latency ever registers, cache it to a file written by a systemd path/timer unit instead.

*Migration cost:* n/a

### ✅ KEEP — CLI tool ring
**Current:** zoxide 0.9.9 / eza 0.23.4 / bat 0.26.1 + bat-extras / fzf 0.73.1 + fzf.fish / yazi 26.5.6 / carapace 1.6.3  
**Alternative:** n/a (television/skim evaluated for fzf slot; none warrant a move)

Every member verified alive and current in the lock; none is superseded in 2026. The only oxidation argument is fzf (Go) vs television/skim (Rust), but fzf 0.73 is actively shipping, the fzf.fish plugin wires it into fish keybindings, and television targets a channel-browser niche rather than the preview-widget role fzf fills here — switching buys aesthetics, costs working integration. Carapace still earns its slot beside fish 4's native completions for the long tail (gh, nix subcommands). Yazi's 26.x versioning and the shellWrapperName comment show the config is already tracking upstream renames — the maintenance loop is working.

*Migration cost:* n/a


## Lens: dev-tooling

### ✅ KEEP — Editor
**Current:** VSCode + official Anthropic extension (home/vscode.nix)  
**Alternative:** n/a (re-evaluate trigger: Anthropic ships first-party ACP/Zed support)

Half the Feb 2026 rejection rationale expired — Zed is post-1.0 now (1.4.4 in the locked nixpkgs) — but the half that matters got worse, not better: Anthropic still has not adopted ACP, Zed's Claude Code is a Zed-built bridge around a vendored SDK, and it runs 10-20 Claude Code releases (~1-2 weeks) behind because of Zed's weekly cycle (blog.yamk.net April 2026; zed.dev/blog/claude-code-via-acp). The philosophy explicitly trades supply-chain pinning for Claude-tooling freshness — accepting a permanent two-week lag on the one tool that IS the point inverts that. The vscode.nix two-ring setup (Nix installs binary, Marketplace owns extensions) is also exactly the post-March-failure shape; Zed would need the same design rebuilt. The header comment's revisit condition ('when Anthropic adopts ACP') remains unmet — keep, and keep the condition.

*Migration cost:* n/a — if the trigger fires later: home/vscode.nix → Zed settings.json (plain text, agent-friendly), Stylix theme hookup, re-seed keybindings

### 🧪 TRIAL — Version control
**Current:** git (home/git.nix) with Claude-constitution hooks built on the staging area  
**Alternative:** jujutsu 0.42.0 in colocated mode, on transporter and personal repos first — NOT the claudeos repo yet

jj is maximally the owner's taste — Rust, Google-production-validated, every operation undoable (jj undo), conflicts as storable states — and Claude-as-maintainer lowers migration toil. But there's a hard blocker found in this audit: the constitution's pre-commit-gate.sh string-matches 'git commit' and gates on 'git diff --cached'; jj has no staging area, so 'jj commit'/'jj describe' silently bypasses the mechanical untested-commit gate — the constitution would become advisory, the exact failure the philosophy forbids. self-heal, auto-update, and morning-desk all shell out to git too (colocated mode keeps them working, but agents and human would speak different VCS dialects). Mature jj Agent Skills exist in 2026 (danverbraganza/jujutsu-skill etc.), so the agent-friendliness story is solved upstream. Prove it on transporter with a rewritten jj-aware gate hook before gti or this repo.

*Migration cost:* Rewrite pre-commit-gate.sh to intercept jj commands (gate on snapshot diff, not index), add a jj skill to .claude/skills, verify flake eval + 'git add for flake visibility' workflow under colocation, audit 3 modules that run git

### 🔄 SWITCH — Nix LSP
**Current:** nil (modules/common/system.nix + wired into VSCode via nix.serverPath)  
**Alternative:** nixd 2.9.1 (keep nixfmt as formatter, keep statix/deadnix as linters)

nil is effectively unmaintained — the locked nixpkgs version is dated 2025-06-13, a year stale — while nixd 2.9.1 is actively developed and the vscode-nix-ide extension has flipped its default serverPath to nixd. The decisive feature for this repo: nixd evaluates against the real flake, giving completion and hover for NixOS/home-manager *options* across a multi-host configuration — precisely what both the owner and agent-driven edits touch daily, and what nil's syntax-only model can never offer. Stale tooling on the hot path fails the oxidized/bleeding-edge tenet on its own. statix/deadnix survive: nixd doesn't cover their lint classes.

*Migration cost:* Two files: swap nil→nixd in modules/common/system.nix package list; in home/vscode.nix set nix.serverPath="nixd" and translate serverSettings (nixd takes formatting.command and per-flake options expressions); rebuild both hosts

### ✅ KEEP — Git TUI
**Current:** lazygit (home/shell/cli-tools.nix)  
**Alternative:** n/a (lazyjj 0.6.1 is the successor IF the jj trial graduates)

The oxidized instinct says gitui (Rust), but gitui 0.28.1 still self-describes as beta with slower development, while lazygit 0.62.2 ships releases through April 2026 with best-in-class interactive rebase. A TUI is purely human-facing — agents never touch it — so churn here buys zero Claude-integration value, and 'Rust' alone doesn't outrank maturity when the tool isn't plumbing. The real future decision is coupled to the jj trial: if jj graduates, replace lazygit with lazyjj (already in the locked nixpkgs) rather than relitigating gitui.

*Migration cost:* n/a — one line in cli-tools.nix either way

### ✅ KEEP — Diff pager
**Current:** delta (home/git.nix, Stylix-themed)  
**Alternative:** n/a — optionally add difftastic as a 'git dft' alias for semantic review, zero displacement

Difftastic's semantic diffs are appealing but it structurally cannot replace delta: it can't act as interactive.diffFilter (breaks git add -p), can't produce applyable patches, and lazygit's pager integration assumes line-oriented output. Delta 0.19.2 is feature-complete (hyperlinks, navigate, Stylix theming already wired) even if development has slowed — a finished human-facing pager is fine; it's not plumbing under active churn. Crucially, agents read raw 'git diff' output, never the pager, so this choice has zero Claude-integration weight. Adding difftastic alongside as an opt-in alias satisfies the bleeding-edge itch without ripping out working integration.

*Migration cost:* n/a — optional: one alias + one package in home/git.nix

### ✅ KEEP — Per-project environments
**Current:** direnv + nix-direnv (home/shell/cli-tools.nix)  
**Alternative:** n/a

This is the ephemerality tenet operationalized: dev shells appear on cd, vanish on exit, nothing installed globally, nix-direnv pins the shell against GC. It is also the most agent-friendly option available — plain-text .envrc, and Claude Code's Bash tool inherits the environment with zero per-session setup, versus devenv/flox which add a daemon or service layer (the second-brain trap in miniature). Nothing in 2026 displaces it; the mkhl.direnv VSCode extension and the direnv.restart.automatic setting in vscode.nix complete the loop. Survives fresh scrutiny without caveats.

*Migration cost:* n/a


## Lens: apps-desktop

### ✅ KEEP — Browser
**Current:** google-chrome (modules/apps/default.nix)  
**Alternative:** n/a

Claude integration is the point of this OS, and the Claude-in-Chrome extension officially supports only Chrome and Edge — not Firefox, Zen, Brave, or even other Chromium forks like Vivaldi (verified via Anthropic's help center and Claude Code docs, June 2026). The claude-in-chrome MCP server is live in this repo's tooling, so the extension is load-bearing, not aspirational. The March-2026 failure post-mortem explicitly lists Chrome-extension pain as a reason ClaudeOS died once; re-introducing that risk for browser aesthetics would fight the founding lesson. Locked flake has Chrome 149 — current and auto-tracking nixpkgs unstable.

*Migration cost:* n/a — though note gnome.nix hides com.google.Chrome from the launcher; verify that's intentional.

### 🔄 SWITCH — Image viewer
**Current:** imv 5.0.1 (home/imv.nix + 7 image mime defaults in home/default.nix)  
**Alternative:** Loupe (org.gnome.Loupe) — already in the gti closure at v50.0

imv fails fresh scrutiny on three philosophy axes. (1) It's a Niri-era leftover — home/imv.nix literally says 'Start in fullscreen for tiling WM' — and on Mutter it renders without any window decorations because GNOME rejects xdg-decoration and imv draws no CSD (verified via GNOME Discourse and known non-GTK-app reports). (2) Upstream is effectively unmaintained (last release 5.0.1 ~2023, author inactive, community soft-forks), violating the bleeding-edge taste. (3) Loupe is GTK4 + Rust with sandboxed glycin loaders — it IS the oxidized choice — and the DE pivot rationale ('first-class app integration beat Niri') applies directly. It's already installed via GNOME core, so imv is pure duplicate closure weight.

*Migration cost:* Delete home/imv.nix (and its import in home/default.nix), remap the 7 image/* mime defaults to org.gnome.Loupe.desktop; lose custom Colemak binds (Loupe's arrow-key defaults already match the spirit of them).

### 🔄 SWITCH — Communication apps
**Current:** slack + discord + teams-for-linux as Nix system packages  
**Alternative:** Chrome PWAs (app.slack.com, teams.microsoft.com, discord.com) — keep discord package only if voice/screenshare proves essential

Three Electron repacks of web apps is the March failure pattern: Nix owning a fast-moving proprietary layer. Discord notoriously refuses to launch until nixpkgs catches its forced update — a recurring papercut the two-ring rule exists to prevent; teams-for-linux (v2.11.1) is a third-party Electron wrapper around the same web app Microsoft already serves first-class in Chrome. PWAs auto-update (ring 2), drop three Electron runtimes from the closure, leave no Nix-side cruft, and — the kicker — live inside Chrome where Claude-in-Chrome can read and drive them, which standalone Electron windows cannot offer. Discord is the only caveat: web Discord limits screenshare/push-to-talk, so trial it first.

*Migration cost:* Remove 3 packages from modules/apps/default.nix; one-time imperative PWA installs in Chrome (correct ring-2 behavior); test Discord voice on web before deleting that package.

### ✅ KEEP — Knowledge management
**Current:** obsidian 1.12.7 (with imperatively-installed community plugins)  
**Alternative:** n/a (Logseq and plain-markdown-only both rejected)

Obsidian survives because its data layer is exactly the agent-friendly substrate the philosophy demands: a plain-Markdown vault Claude can read, write, and grep with zero API — the app is just a human lens over files, not a second brain. Logseq is now the worse choice on these tenets: its DB-based rewrite moved truth out of plain files. 'Plain markdown + Claude' alone loses graph view, mobile sync, and the Web Clipper for no gain since Obsidian costs nothing in lock-in. The existing pattern (Nix installs the app, plugins managed imperatively per the comment in default.nix) is textbook two-ring discipline.

*Migration cost:* n/a

### ✅ KEEP — PDF viewer
**Current:** zathura 2026.05.20 (home/zathura.nix, default for application/pdf)  
**Alternative:** n/a (Papers 50.0 already in closure as the annotation/forms fallback)

Unlike imv, zathura passes fresh scrutiny: actively maintained (nixpkgs version dated 2026-05-20), GTK so it decorates properly on Mutter, plain-text declarative config that Stylix themes and an agent can edit, and its recolor feature (documents re-rendered in the base16 palette) is something Papers simply doesn't offer. The Colemak mappings represent real invested config that works. Papers — GNOME's Rust-ified Evince fork — is already in the GNOME closure at v50.0, so the fallback for annotations/forms costs zero; there is no case for making it the default and moving config into GSettings, which is less agent-legible than the current Nix module.

*Migration cost:* n/a

### ✅ KEEP — Fonts
**Current:** Inter (UI, mirrors Claude AI typography) + JetBrainsMono Nerd Font + Fira Code Nerd Font + Noto/DejaVu fallbacks (modules/desktop/fonts.nix, lib/theme.nix)  
**Alternative:** n/a (optional trim: drop nerd-fonts.fira-code)

The stack is current taste, not legacy: Inter-as-UI deliberately mirrors claude.ai — on-brand for an OS whose identity is Claude integration — and JetBrains Mono remains the consensus 2026 terminal/editor mono. The fonts.nix already implements the modern pattern (Symbols Nerd Font preferred via fontconfig alias before emoji), centralized in lib/theme.nix with no hardcoded strings scattered around — exactly the declarative ring-1 shape. Only nit: nerd-fonts.fira-code duplicates the patched-mono role JetBrains Mono fills and only appears as a deep fallback; dropping it would shave the closure but isn't worth a PR on its own.

*Migration cost:* n/a (one-line package removal if trimming Fira Code)


## Lens: system-plumbing

### 🔄 SWITCH — GitHub token in shell environment
**Current:** fish interactiveShellInit exports GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token) into every interactive shell (home/shell/fish.nix:270)  
**Alternative:** Scoped wrapper: launch the GitHub MCP server (and any plugin that needs it) via a writeShellScriptBin that does `exec env GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token) <server>`; point .mcp.json at the wrapper. systemd user units that need it use `ExecStart` wrappers the same way (or LoadCredential for ring-1 services).

The current export puts a live token in the environ of every process spawned from any shell and runs a `gh auth token` subprocess on every shell start — a per-poll cost paid at the most latency-sensitive moment, for a credential only one or two consumers need. The 2026 zero-friction answer is to keep gh's keyring as the single source of truth (already the case) but materialize the token only in the consuming process's environment via a wrapper script. This is strictly more agent-friendly: the wrapper is plain text in the repo, and Claude sessions inherit nothing they don't need. Same UX, smaller blast radius, faster shells.

*Migration cost:* Remove 4 lines from home/shell/fish.nix; add one writeShellScriptBin and repoint the MCP server command in the (ring-2) .mcp.json.

### ✅ KEEP — Theming engine
**Current:** Stylix with a hand-extracted Claude-brand base16 scheme (modules/desktop/theme.nix), consumed by ghostty/vscode/macchina/morning-desk via config.lib.stylix.colors and ~/.config/stylix/palette.json  
**Alternative:** n/a (matugen evaluated and rejected)

matugen is present in the locked nixpkgs (verified: 'Material you color generation tool') but it solves the opposite problem: wallpaper-derived dynamic palettes. ClaudeOS's palette is a fixed brand identity (terracotta/Claude tokens extracted from claude.ai CSS) — there is nothing to 'generate', and matugen-class tools are runtime templaters that would push theming into ring 2 and fight home-manager exactly the way the March failure did. Stylix is declarative, plain-text, base16-addressable from any module, and already exports palette.json that morning-desk reads. For GNOME specifically, GNOME 47+ native accent colors are a complement, not a replacement. The incumbent survives fresh scrutiny cleanly; only the empty `colors = { }` placeholder in lib/theme.nix is cruft worth deleting in passing.

*Migration cost:* n/a

### 🧪 TRIAL — Network management
**Current:** NetworkManager + systemd-resolved + nftables (modules/common/networking.nix)  
**Alternative:** Keep NetworkManager; set networking.networkmanager.wifi.backend = "iwd" on transporter first (option verified present in the locked flake)

Honest take: full systemd-networkd+iwd is wrong for these machines despite the oxidized itch — GNOME Shell's network indicator and the Settings panel hard-depend on NetworkManager, so dropping it breaks the first-class GNOME integration that motivated the 2026-06 DE pivot. nmcli is also among the most scriptable, agent-friendly network CLIs there is. The bleeding-edge win available without that cost is the iwd backend: iwd does the 802.11 work (faster scans, better roaming, WPA3) while NM keeps the GNOME face. That's a one-line change and exactly what transporter exists to prove before gti.

*Migration cost:* One line in modules/common/networking.nix gated to transporter initially; existing wpa_supplicant-saved Wi-Fi profiles need re-entering passphrases once.

### 🗑 DROP — SSH brute-force protection
**Current:** fail2ban with aggressive sshd jail (modules/common/networking.nix)  
**Alternative:** Nothing — key-only sshd with modern-crypto-only KexAlgorithms/Ciphers is already the complete defense

Both hosts are laptops on a home LAN, PasswordAuthentication is off, and the cipher/kex allowlist already rejects legacy clients — there is no credential for fail2ban to protect. Meanwhile it's a permanently-resident daemon tailing the journal (a per-poll cost the doctrine forbids for LLMs and should frown on for CPUs too), it maintains mutable nftables ban state that violates 'trace-free, no cruft', and on a roaming laptop behind shared NATs it can ban *you*. This is server reflex copied onto a laptop; the recent modernization missed it.

*Migration cost:* Delete the 12-line services.fail2ban block in modules/common/networking.nix; nothing else references it.

### 🗑 DROP — Boot splash
**Current:** Plymouth with Stylix-themed Claude logo + quiet/splash kernel params (modules/common/boot.nix)  
**Alternative:** Plain quiet systemd-boot; restore boot.loader.systemd-boot.configurationLimit toward 10

boot.nix itself documents the cost: kernel+initrd is '~60-90MB with plymouth' per generation, which is why rollback headroom was cut from 10 generations to 5 on a 1G ESP. For an OS whose maintainer is an agent that auto-updates weekly and self-heals via PRs, generation rollback depth is operational capacity — trading half of it for a splash screen on a laptop that boots in seconds via systemd-initrd is a bad trade. It also works against 'the system narrates itself': the named-generation boot menu is the narration; plymouth just hides the journal. The Claude branding survives elsewhere (macchina art notwithstanding, the boot menu slug names are the identity that matters).

*Migration cost:* Remove the plymouth block, stylix.targets.plymouth, and the 'splash' kernel param in modules/common/boot.nix; bump configurationLimit; one rebuild.

### 🗑 DROP — First-shell MOTD
**Current:** macchina fetch (host/distro/DE/shell/uptime/memory/packages + clawd ASCII) on first shell, followed by the daily-brief cat (home/macchina.nix, home/shell/fish.nix)  
**Alternative:** Keep only the daily-brief tail from claude-monitor/morning-desk; delete home/macchina.nix

Macchina prints facts that never change (distro, DE, shell) plus minutiae (package count) on every first terminal — it is precisely the 'pipeline ending in a string' widget the proactivity doctrine calls a wrong draft, and it now duplicates the sanctioned surface: morning-desk's dashboard and the daily-brief.txt that fish already prints two lines later. 'One thing, never a feed' means the brief is the one thing; a spec sheet above it dilutes it. The clawd ASCII is charming but branding is not information — if missed, it can be a 3-line echo without a fetch tool, its config file, and its theme template.

*Migration cost:* Delete home/macchina.nix and its import in home/default.nix; trim ~4 lines of fish interactiveShellInit (keep the MACCHINA_SHOWN-guarded brief cat, renamed).
