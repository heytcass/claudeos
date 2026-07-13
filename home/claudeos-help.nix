# home/claudeos-help.nix — ClaudeOS capability discovery command.
# Defines the `claudeos` Fish function: a workflow-oriented guide to all
# Claude integrations, themed with the Stylix base16 palette.
#
# The desktop keybinding rows are GENERATED from lib/keybindings.nix (the
# same list home/gnome.nix binds), so they cannot drift. The rest below
# still hand-mirrors definitions elsewhere — keep in sync when changing:
#   terminal commands   → home/shell/fish.nix (functions)
#   Claude Code skills/MCP → home/claude-code.nix, .claude/
#   background services → modules/apps/claude-monitor, modules/apps/jasper.nix
{ lib, ... }:

let
  keybindingRows = lib.concatMapStrings (b: ''
    set_color $key; printf "    %-22s " "${b.display}"
    set_color $desc; echo "${b.help}"
  '') (import ../lib/keybindings.nix);
in
{
  programs.fish.functions.claudeos = ''
        # Read Stylix palette for themed output
        set -l p "$HOME/.config/stylix/palette.json"
        set -l title normal
        set -l heading normal
        set -l key normal
        set -l desc normal
        set -l dim normal

        if test -f "$p"; and command -q jq
          set title (jq -r '.base0D' $p)
          set heading (jq -r '.base0E' $p)
          set key (jq -r '.base0B' $p)
          set desc (jq -r '.base05' $p)
          set dim (jq -r '.base03' $p)
        end

        echo ""
        set_color --bold $title
        echo "  ClaudeOS"
        set_color normal
        echo ""

        # ── Desktop ──────────────────────────────────────────────
        set_color --bold $heading
        printf "  %-37s" "FROM YOUR DESKTOP"
        set_color $dim
        echo "any window, no terminal needed"
        set_color normal

    ${keybindingRows}
        # Not an OS binding: Claude Desktop registers this global shortcut itself
        # (ring 2 — the app owns it, we just surface it)
        set_color $key; printf "    %-22s " "Ctrl+Alt+Space"
        set_color $desc; echo "Claude Desktop — full chat UI (app's own shortcut)"
        set_color normal
        echo ""

        # ── Terminal ─────────────────────────────────────────────
        set_color --bold $heading
        echo "  IN YOUR TERMINAL"
        set_color normal

        set_color $key; printf "    %-22s " 'ask "..."'
        set_color $desc; echo "Quick answer right in your terminal (like Super+A but inline)"
        set_color $key; printf "    %-22s " "fix"
        set_color $desc; echo "Last command failed? Suggests the corrected version"
        set_color $key; printf "    %-22s " "explain"
        set_color $desc; echo "Explain last command, or pipe any output to understand it"
        set_color $key; printf "    %-22s " "rebuild"
        set_color $desc; echo "Full rebuild: snapshot → nixos-rebuild → auto-commit + push"
        set_color $key; printf "    %-22s " "usage"
        set_color $desc; echo "Claude subscription limits (same data as the bar's ring)"
        set_color $key; printf "    %-22s " 'wish "..."'
        set_color $desc; echo "Describe a change in plain words — the OS writes itself a PR"
        set_color $key; printf "    %-22s " 'why "..."'
        set_color $desc; echo "Ask why the machine is doing something — diagnosis with evidence"
        set_color $key; printf "    %-22s " "wherewasi"
        set_color $desc; echo "Reconstruct what you were doing — structured state, no surveillance"
        set_color $key; printf "    %-22s " "claudeos"
        set_color $dim; echo "You're looking at it"
        set_color normal
        echo ""

        # ── Claude Code ──────────────────────────────────────────
        set_color --bold $heading
        printf "  %-37s" "INSIDE CLAUDE CODE"
        set_color $dim
        echo "Claude already knows about these"
        set_color normal

        set_color $key; printf "    %-22s " "/deploy"
        set_color $desc; echo "Validate → build → apply NixOS config"
        set_color $key; printf "    %-22s " "/add-module"
        set_color $desc; echo "Scaffold a new module, wire it in, validate"
        set_color $key; printf "    %-22s " "MCP: nixos"
        set_color $desc; echo "Search NixOS options and packages"
        set_color $key; printf "    %-22s " "MCP: system-health"
        set_color $desc; echo "Check disk, services, journal, memory, snapshots"
        set_color normal
        echo ""

        # ── Background ───────────────────────────────────────────
        set_color --bold $heading
        echo "  RUNNING IN THE BACKGROUND"
        set_color normal

        set_color $key; printf "    %-22s " "Health monitor"
        set_color $desc; echo "Checks every 15 min — notifies if something breaks"
        set_color $key; printf "    %-22s " "Daily brief"
        set_color $desc; echo "System summary at 9 AM, shown in first terminal"
        set_color $key; printf "    %-22s " "Jasper"
        set_color $desc; echo "Personal companion lane — in progress (bar face pending)"
        set_color normal
        echo ""
  '';
}
