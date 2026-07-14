# home/claude-code.nix — Claude Code configuration, two-ring style.
# Nix SEEDS ~/.claude/settings.json on first activation but never overwrites it
# afterwards — Claude Code and /config own the live file. To re-seed from Nix:
# delete the file and rebuild. (Force-managing it meant every plugin experiment
# required a nix edit + rebuild, which is exactly the friction this avoids.)
#
# MCP servers are NOT seeded here: ~/.claude/.mcp.json turned out to be a path
# Claude Code never reads (user scope lives in ~/.claude.json, project scope in
# <repo>/.mcp.json). The claudeos servers (nixos, system-health) are registered
# in the repo's tracked .mcp.json — Ring 1, versioned, no seed dance. This
# module just puts their binaries on PATH.
{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Statusline script — reads Stylix palette for themed Claude Code status bar.
  # Installed as a stable command on PATH so the seeded settings.json never
  # points at a store path that could be garbage-collected.
  statuslineScript = pkgs.writeShellScriptBin "claude-statusline" ''
    PALETTE="$HOME/.config/stylix/palette.json"

    color() {
        local hex
        hex=$(${pkgs.jq}/bin/jq -r ".$1" "$PALETTE" 2>/dev/null)
        if [ -n "$hex" ] && [ "$hex" != "null" ]; then
            printf '\033[38;2;%d;%d;%dm' "0x''${hex:0:2}" "0x''${hex:2:2}" "0x''${hex:4:2}"
        fi
    }

    red=$(color base08)
    orange=$(color base09)
    yellow=$(color base0A)
    green=$(color base0B)
    cyan=$(color base0C)
    blue=$(color base0D)
    purple=$(color base0E)
    white=$(color base05)
    dimmed=$(color base03)
    reset='\033[0m'

    input=$(cat)

    cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir')
    model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name')
    used_pct=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // empty')
    total_input=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.total_input_tokens // 0')
    total_output=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.total_output_tokens // 0')

    dir_display=$(echo "$cwd" | sed "s|^$HOME|~|" | awk -F/ '{
        if (NF <= 3) print $0;
        else printf "%s/%s/%s", $(NF-2), $(NF-1), $NF
    }')

    git_info=""
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git -C "$cwd" -c core.useOptionalLocks=false branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            git_info=" ''${orange} ''${branch}''${reset}"
            git_status=$(git -C "$cwd" -c core.useOptionalLocks=false status --porcelain 2>/dev/null)
            modified=$(echo "$git_status" | grep -c "^ M")
            staged=$(echo "$git_status" | grep -c "^[MADRC]")
            untracked=$(echo "$git_status" | grep -c "^??")
            status_info=""
            [ "$staged" -gt 0 ] && status_info="''${status_info}''${green}+''${staged}''${reset}"
            [ "$modified" -gt 0 ] && status_info="''${status_info}''${red}!''${modified}''${reset}"
            [ "$untracked" -gt 0 ] && status_info="''${status_info}''${red}?''${untracked}''${reset}"
            [ -n "$status_info" ] && git_info="''${git_info} ''${status_info}"
        fi
    fi

    model_short=$(echo "$model" | sed 's/Claude //')

    context_info=""
    if [ -n "$used_pct" ]; then
        pct=$(printf "%.0f" "$used_pct")
        if [ "$pct" -gt 75 ]; then
            context_info=" ''${red}ctx:''${pct}%%''${reset}"
        elif [ "$pct" -gt 50 ]; then
            context_info=" ''${yellow}ctx:''${pct}%%''${reset}"
        else
            context_info=" ''${cyan}ctx:''${pct}%%''${reset}"
        fi
    fi

    cost=""
    if [ "$total_input" -gt 0 ] || [ "$total_output" -gt 0 ]; then
        cost_val=$(awk "BEGIN {printf \"%.2f\", ($total_input * 3 + $total_output * 15) / 1000000}")
        cost=" ''${dimmed}\$''${cost_val}''${reset}"
    fi

    printf "''${white}''${dir_display}''${reset}''${git_info} ''${purple}''${model_short}''${reset}''${context_info}''${cost}\n"
  '';

  # Agent-pulse hook — the bar island's "✳ working" breath for interactive
  # Claude Code sessions (headless automations pulse via lib/claude-script.nix
  # instead, and pass their phrase through CLAUDEOS_AGENT_ACTIVITY, which the
  # claude CLI's child processes — including this hook — inherit).
  # begin on UserPromptSubmit, refresh (mtime) on every PostToolUse so turns
  # longer than the bar's 60-min staleness backstop keep breathing, end on
  # Stop/SessionEnd. Marker per session id, so concurrent sessions coexist.
  # begin derives its phrase from the submitted prompt itself (UserPromptSubmit's
  # JSON payload includes `.prompt`): the first four words go up instantly as a
  # placeholder, then a backgrounded haiku call rewrites the marker with a
  # bespoke 3-4 word summary a moment later. UserPromptSubmit hooks BLOCK the
  # turn, so the LLM call must never run in the foreground; and the summarizer
  # is itself a claude session whose hooks would recurse, so it exports
  # CLAUDEOS_AGENT_SUMMARIZER and the hook mutes itself under that flag.
  # The generic "working with Tom" fallback only fires when no prompt text is
  # available at all.
  agentHookScript = pkgs.writeShellScriptBin "claudeos-agent-hook" ''
    [ -n "''${CLAUDEOS_AGENT_SUMMARIZER:-}" ] && exit 0
    dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudeos-agent.d"
    input=$(cat)
    sid=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.session_id // empty' 2>/dev/null)
    [ -n "$sid" ] || exit 0
    f="$dir/claude-$sid"
    case "''${1:-}" in
      begin)
        mkdir -p "$dir"
        activity="''${CLAUDEOS_AGENT_ACTIVITY:-}"
        if [ -z "$activity" ]; then
          activity=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '(.prompt // "") | [scan("\\S+")] | .[0:4] | join(" ")' 2>/dev/null)
        fi
        printf '%s\n' "''${activity:-working with Tom}" > "$f"
        # Sharpen the placeholder asynchronously: a detached haiku call writes
        # the bespoke phrase over the marker when it returns. Skipped when a
        # curated phrase came in via CLAUDEOS_AGENT_ACTIVITY (headless lanes).
        # The [ -f ] re-check keeps a slow summary from resurrecting a marker
        # the Stop hook already removed (which would pin a ghost pill until
        # the bar's 60-min backstop). Failures/timeouts leave the placeholder.
        if [ -z "''${CLAUDEOS_AGENT_ACTIVITY:-}" ] && [ -x "$HOME/.local/bin/claude" ]; then
          prompt=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.prompt // empty' 2>/dev/null | head -c 1500)
          if [ -n "$prompt" ]; then
            (
              export CLAUDEOS_AGENT_SUMMARIZER=1
              summary=$(timeout 30 "$HOME/.local/bin/claude" -p "Summarize this request as a short activity phrase for a status pill: 3-4 words, present-participle verb first (like: fixing login bug / reviewing PR 58 / tuning bar colors). Output ONLY the phrase — no quotes, no punctuation, no markdown.

    Request: $prompt" --model haiku --strict-mcp-config 2>/dev/null | head -n 1)
              [ -n "$summary" ] && [ -f "$f" ] && printf '%s\n' "$summary" > "$f"
            ) </dev/null >/dev/null 2>&1 &
          fi
        fi
        ;;
      refresh) [ -f "$f" ] && touch "$f" ;;
      end) rm -f "$f" ;;
    esac
    exit 0
  '';

  # Hook stanzas shared by the seed below and the live-settings merge in the
  # activation snippet. `|| true` + stderr drop: a missing command (e.g. a
  # session running before the rebuild that installs it) must never banner
  # the user or block a prompt.
  agentHooks = {
    UserPromptSubmit = [
      {
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook begin 2>/dev/null || true";
          }
        ];
      }
    ];
    PostToolUse = [
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook refresh 2>/dev/null || true";
          }
        ];
      }
    ];
    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook end 2>/dev/null || true";
          }
        ];
      }
    ];
    SessionEnd = [
      {
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook end 2>/dev/null || true";
          }
        ];
      }
    ];
  };

  # Claude Code global settings
  # Plugins: only list globally-enabled plugins here.
  # All others live in the Discover tab — install per-project via /plugin → Discover → Project scope.
  claudeSettings = {
    statusLine = {
      type = "command";
      command = "claude-statusline";
    };
    enabledPlugins = {
      "github@claude-plugins-official" = true;
      "learning-output-style@claude-plugins-official" = true;
      "telegram@claude-plugins-official" = true;
    };
    skipDangerousModePermissionPrompt = true;
    permissions = {
      allow = [
        "mcp__plugin_telegram_telegram__reply"
        "mcp__plugin_telegram_telegram__react"
        "mcp__plugin_telegram_telegram__edit_message"
        "mcp__claude_ai_Google_Calendar__list_events"
        "mcp__claude_ai_open-brain__search_thoughts"
        "mcp__claude_ai_open-brain__list_thoughts"
        "mcp__claude_ai_open-brain__thought_stats"
        "mcp__claude_ai_open-brain__capture_thought"
        "CronCreate"
        "CronDelete"
      ];
    };
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    hooks = agentHooks;
  };

  settingsSeed = pkgs.writeText "claude-settings-seed.json" (builtins.toJSON claudeSettings);
  agentHooksJson = pkgs.writeText "claudeos-agent-hooks.json" (builtins.toJSON agentHooks);
in
{
  home.packages = [
    statuslineScript
    agentHookScript
    # mcp-nixos binary for the repo's .mcp.json "nixos" server entry.
    inputs.mcp-nixos.packages.${pkgs.system}.default
  ];

  # Seed ~/.claude/settings.json only if it doesn't exist — the live file is
  # mutable and owned by Claude Code from then on.
  home.activation.seedClaudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.claude"
    if [ ! -e "$HOME/.claude/settings.json" ]; then
      $DRY_RUN_CMD cp ${settingsSeed} "$HOME/.claude/settings.json"
      $DRY_RUN_CMD chmod u+w "$HOME/.claude/settings.json"
    fi
  '';

  # Same seed philosophy, per-key: machines whose settings.json predates the
  # agent-pulse hooks get the "hooks" key merged in once — only when absent,
  # so the live file keeps owning it afterwards (two-ring rule). Tolerant of
  # malformed JSON: a failed merge must never abort the whole HM activation.
  home.activation.seedClaudeHooks = lib.hm.dag.entryAfter [ "seedClaudeConfig" ] ''
    s="$HOME/.claude/settings.json"
    if [ -e "$s" ] && ! ${pkgs.jq}/bin/jq -e 'has("hooks")' "$s" >/dev/null 2>&1; then
      if ${pkgs.jq}/bin/jq --slurpfile h ${agentHooksJson} '.hooks = $h[0]' "$s" > "$s.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$s.tmp" "$s"
      else
        rm -f "$s.tmp"
        echo "claudeos: could not seed agent-pulse hooks into $s (malformed JSON?)" >&2
      fi
    fi
  '';
}
