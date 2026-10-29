# ClaudeOS - NixOS Configuration

This is a NixOS system configuration repo optimized for tight Claude integration throughout the OS. Never commit untested NixOS changes — but "tested" means the cheapest check that can actually fail on your change, not the most expensive one available. See **Validation economy** below for which check that is.

**Read `docs/PHILOSOPHY.md` before making design decisions.** It captures why ClaudeOS exists, the founding insight (the system is one git repo, so the OS can maintain itself via PRs), the two-ring rule, the proactivity doctrine, decided security trade-offs, and the cost doctrine. If a proposal changes one of its conclusions, update PHILOSOPHY.md in the same PR.

## Environment

User runs NixOS with Hyprland on Wayland + a bespoke Quickshell bar (chosen 2026-07; GNOME was removed entirely in the rip-out — docs/plans/2026-07-11-gnome-ripout-plan.md). Session must be launched via the "Hyprland (UWSM)" entry at the regreet greeter. Fish shell with Starship prompt. Do not assume bash/PS1.

**No system Python, by design.** `python3` is not on PATH, and that's deliberate. Use sed/awk/jq/heredocs for edits. When Python (or any other missing tool) is genuinely needed, run it ad hoc with `nix shell nixpkgs#<pkg> -c …` rather than adding it to the system.

## Theming & Styling

**Always use Stylix/base16 palette references — never hardcode hex color values.** The system uses a unified theming approach via Stylix (defined in `modules/desktop/theme.nix`). When a module needs colors, reference the base16 scheme through `config.lib.stylix.colors` or equivalent — do not paste raw `#rrggbb` values.

## NixOS Configuration

This is a multi-host flake (`gti` primary, `transporter` testbed). Check which hosts a change affects and keep shared settings in `modules/common/` (e.g., Intel microcode was once conditionally set on only one device).

## CRITICAL: Ask Questions, Don't Assume

**Never assume — always use `AskUserQuestion` when anything is unclear.** Ask about: approach choices, which module to use, whether to test/commit/update docs, or if behavior matches expectations.

## Hosts

Always use `$(hostname)` in build/deploy commands rather than hardcoding a host name. Available hosts are defined in `hosts/` and `flake.nix`: `gti` (Dell XPS 13 9370, primary) and `transporter` (Dell Latitude 7280, testbed).

**Stack:** NixOS unstable • Hyprland (Wayland) + Quickshell bar • greetd/regreet • Pipewire • home-manager • sops-nix • Stylix

## Architecture

```
flake.nix              # Entry point — defines all hosts (see hosts/ directory)
lib/mkSystem.nix       # Host builder — wires common modules + home-manager
hosts/<hostname>/      # Per-host: default.nix (overrides) + hardware-configuration.nix
modules/common/        # Shared NixOS config: boot, networking, nix, users, locale, disko
modules/desktop/       # Hyprland + greetd, audio, fonts, Stylix theme
modules/apps/          # System packages: terminals, claude, jasper
home/                  # home-manager modules: shell, git, ghostty, vscode, hyprland, quickshell/
lib/                   # Helpers: mkSystem, hideDesktopEntries, theme utilities
assets/                # Static files (wallpapers, etc.)
```

**Key inputs:** nixpkgs (unstable), home-manager, nixos-hardware, sops-nix, disko, stylix, claude-desktop-linux, nix-index-database, mcp-nixos

home-manager runs as a NixOS module (not standalone) — configured in `lib/mkSystem.nix`.

## Workflow

All work is done directly on NixOS machines:

1. **Edit** configuration in `~/.config/claudeos` (or a worktree of it)
2. **Stage** new files with `git add` — Nix flakes only see tracked files, so an unstaged new file is invisible to every check below
3. **Validate** by climbing the ladder in *Validation economy* to the rung your change needs — never below rung 4 for a `.nix` change
4. **Apply** with `sudo nixos-rebuild switch --flake ~/.config/claudeos#$(hostname)` (or `/deploy`)
5. **Push** with `git push` — remote rebuilds pull from the repo, so never skip this
6. **Sync** between machines with `git pull`

**Important:** Always modify files in `~/.config/claudeos/` — never edit upstream module files or flake input sources directly.

## Validation economy

Match the cost of validation to the change. Run the cheapest check that can actually fail on the kind of mistake you might have made; climb only when it passes and the next rung catches something it cannot. A green check that could never have gone red is not evidence. Equally, a pile of green evals is not a substitute for the one rung that exercises your failure mode — a dry-run will never find a QML typo.

### The ladder (cheapest first)

| # | Rung | Cost | Catches | Cannot catch |
|---|------|------|---------|--------------|
| 0 | **Edit-time hooks** (automatic) — `post-edit-check.sh` runs nixfmt, `nix-instantiate --parse`, and statix on every `.nix` you touch | free | Syntax errors, lint, formatting | Anything that needs evaluation |
| 1 | **`nix fmt`** — treefmt: nixfmt + statix + deadnix. The gate form is `nix fmt -- --ci` (exit 1 if anything would change); `--check` does not exist and always fails | seconds | Formatting, lint, dead bindings — exactly what CI's first step rejects | Semantics |
| 2 | **Targeted eval** — `nix eval .#nixosConfigurations.$(hostname).config.<path>`; for a generated file, `nix eval --raw` its `.text` | seconds | Wrong option name/type in *that* value; whether the rendered value is what you meant | Other hosts; anything outside that attribute; build failures |
| 3 | **Runtime config checks** (`system-health` MCP, live session only) — `hypr_config_check` for new Hyprland lines, `quickshell_check` for QML (pass `qml_dir` from a worktree; briefly restarts the bar) | seconds | Config the Hyprland binary rejects; QML that fails to load and would blank the bar | Hook bodies (use `hyprctl eval`), bind option names (silently dropped — check by eye), how it *looks* (`/qml-dial-in`) |
| 4 | **Eval every host** — `nix flake check --no-build` + `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run` for each host. `claudeos-validate` does both, but it `cd`s to `$CLAUDEOS_DIR` — from a worktree, run the loop by hand or you validate the main checkout | ~1 min | Eval errors, missing options, type errors and assertions on *every* host — including the one you aren't on. The pre-commit hook enforces the `--no-build` half for staged `.nix` | Derivations that fail to build; anything at runtime |
| 5 | **Full build of the affected host** — `nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel` | seconds to an hour (incremental on the running host; cold after a lock bump) | Build-time failures: patches that no longer apply, overrides/overlays that fail, `writeShellScriptBin` syntax checks on embedded scripts (every `mkClaudeScriptBin`), packages removed upstream | Boot and runtime behaviour |
| 6 | **`nix flake check`** (no `--no-build`) — `checks` *are* every host's toplevel, so this builds all of them | rung 5 × hosts (toplevels already in the store are skipped) | Build failures on the host you aren't on | Same as rung 5 |
| 7 | **VM boot test** — `nix build .#nixosConfigurations.$(hostname).config.system.build.vm`, run `./result/bin/run-$(hostname)-vm`, grep the serial log for `CLAUDEOS-SMOKE-PASS`. Needs `/dev/kvm`. The weekly auto-update lane (`modules/common/auto-update.nix`) runs this for every lock bump before it may apply | minutes | Units that fail at boot, multi-user/display-manager not coming up; also prints a whole-config Hyprland `--verify-config` verdict (reported, not yet gating) | Real hardware (thermald, scx, fwupd, throttled, disko are stripped in the VM), GPU and the session (headless — QML never runs), sops secrets (cannot decrypt) |
| 8 | **`nixos-rebuild switch`** — then `hypr_config_errors` and `failed_services` | real | Everything, on real hardware — the only rung that does | Nothing; rollback is a generation away, so for experimental components follow PHILOSOPHY.md's blast-radius rule |

CI (`validate.yml`) runs rung 1, the rung-4 dry-runs, and rung 5 for transporter only, on every PR — so nothing merges below that, but CI never runs 3 or 7, and its rung 5 is on the host you're probably not on.

### Minimum rung by change type

| Change | Minimum before commit | Add when |
|--------|-----------------------|----------|
| Docs-only (`*.md` no Nix expression reads) | none — `nix fmt -- --ci` if you touched anything else | — |
| Nix module value / option | 4 | 5 if it adds or overrides a package, adds an overlay/patch, or edits an embedded shell script |
| Hyprland config (`home/hyprland.nix`) | 3 (`hypr_config_check` on each new line) + 4 | 2 to read the generated `hyprland.lua` before trialling it; `hyprctl eval` for any hook body |
| Quickshell QML (`home/quickshell/`) | 3 (`quickshell_check`) | 4 if `home/hyprland.nix` changed too (Theme.qml is generated there) |
| New package / overlay / input override | 5 | 6 if it differs per host |
| `flake.lock` bump | 6 | 7 — or let the weekly auto-update lane do it; a Dependabot lock PR gets only CI's rungs |
| Boot, greeter, display manager, systemd units | 5 | 7 before switching — a broken greeter means no way to log in |

Before `/deploy` and `switch`, the deploy skill runs 1, 4, and 5 on the target; rung 8 is the switch itself.

## Compositor config isn't validated by the build

`nix build` / `nix flake check` only check Nix **evaluation** — they cannot parse the *contents* of a generated `hyprland.conf` or the Quickshell QML. A config that builds green can still be rejected at runtime: e.g. Hyprland 0.55 changed `windowrule` grammar to space-separated (`float class:^(…)$`), so the old comma form (`float, class:…`) builds fine but throws `invalid field float` and raises Hyprland's on-screen config-error banner. Likewise a single broken QML file blanks the entire bar (Quickshell registers the config dir as one module).

So validate **new Hyprland config values against the Hyprland binary** before rebuilding. The `system-health` MCP server wraps this workflow as tools: `hypr_config_check` (appends a trial line to a temp copy of the deployed config and parses it with `Hyprland --verify-config` — nothing is mutated, no reload, no live session required), `hypr_config_errors` (empty = green), and `quickshell_check` (overlays repo QML onto the deployed config and load-checks with `qs -p`; pass `qml_dir` from worktrees).

Manual fallback: `Hyprland --verify-config -c <file>` must print `config ok`, and `qs -p <writable copy>/shell.qml` must load with no errors. Three traps worth knowing:

- **`XDG_RUNTIME_DIR` must be set** or Hyprland aborts with `XDG_RUNTIME_DIR is not set!` and exit 134 — *identically for a good and a bad config*. Never read that abort as a verdict; it means the verifier didn't run.
- **Do not reach for `hyprctl keyword`.** It is gated on `CONFIG_LEGACY`, and `hyprctl eval` on `CONFIG_LUA` (`src/debug/HyprCtl.cpp`) — exact mirror images. Whichever you pick is broken on the other config format, which is why the tooling moved to `--verify-config`.
- **Under Lua, `--verify-config` executes the config.** A top-level `hl.exec_cmd` runs for real; the same call inside `hl.on("hyprland.start", …)` does not. Keep `exec-once` in the start hook.
- **`config ok` does not mean the hooks work.** `--verify-config` checks that the config *parses and loads*; a hook body only runs when its event fires, so a bad call inside one is invisible to every build-time gate. Test hook bodies by pasting them into `hyprctl eval` — same Lua runtime, same API objects, live. (`eval` prints only `ok`, so smuggle values out via `error(tostring(x))`.)
- **The shipped Lua API stub types most methods as `fun(...)`.** `share/hypr/stubs/hl.meta.lua` (in the Hyprland store path) lists every event name and object field, but its vararg signatures hide real argument shapes — two found the hard way, 2026-08-25: `HL.Monitor:set_workspace` wants a spec table (`{ workspace = 2 }`, not a bare id) while `HL.WorkspaceRule:set_enabled` wants a plain boolean. Confirm against `hyprctl eval` before trusting a signature.
- **Workspace rules for the same workspace MERGE, last registration winning.** Two rules binding one workspace to different monitors do not conflict-and-error, they silently combine — and `settings.workspace_rule` renders *after* the `settings.on` block, so a static rule beats one registered in a hook. For a workspace whose monitor varies by context, keep exactly one rule *enabled* (`set_enabled`) rather than mixing a static rule with a dynamic one. Inspect the live result with `hyprctl workspacerules`.

## Capabilities

Read `CAPABILITIES.md` for the full system capabilities reference — MCP servers, agents, skills, hooks, desktop integration, and proactive behaviors.

## Debugging / NixOS

When diagnosing NixOS build issues, trace the actual dependency chain (e.g., `nix why-depends`, grep for the package in flake inputs and modules) rather than guessing the source. Do not add config options without verifying they exist in the relevant NixOS module.

**Never write option names or package references from memory** — query the `nixos` MCP server first (it covers NixOS options, packages, home-manager/darwin options, Nix functions via noogle, NixOS Wiki, and version history via `nix_versions`).

## Documentation

Documentation lives in `docs/` and `INSTALL.md` — check there for workflow, deployment, hardware, theme, and troubleshooting details.
