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

  # Claude Code → bar hook. Since 2026-11-08 this carries ONE signal, the
  # "blocked on you" twinkle: the bar's Sonic plays it when a session asks a
  # question or waits on a permission. Everything else the bar wants to know
  # about interactive sessions — which exist, their titles, busy or idle — it
  # reads from the files the app already publishes (~/.claude/sessions/
  # <pid>.json, see home/quickshell/Sessions.qml). The per-prompt marker
  # files and the haiku phrase summarizer this hook used to run were retired
  # with that: an app title is stable where a per-prompt phrase churned, and
  # several sessions no longer fight over one island phrase by mtime.
  # Headless lanes still pulse through lib/claude-script.nix.
  # begin/refresh/end are accepted as no-ops so a live settings.json that
  # still carries the old stanzas (until the prune below runs) stays silent.
  agentHookScript = pkgs.writeShellScriptBin "claudeos-agent-hook" ''
    cat >/dev/null
    case "''${1:-}" in
      # Detached so a missing/slow bar never holds the hook up.
      waiting) (${pkgs.quickshell}/bin/qs ipc call sonic waiting </dev/null >/dev/null 2>&1 &) ;;
    esac
    exit 0
  '';

  # Hook stanzas shared by the seed below and the live-settings merge in the
  # activation snippet. `|| true` + stderr drop: a missing command (e.g. a
  # session running before the rebuild that installs it) must never banner
  # the user or block a prompt.
  agentHooks = {
    # "Blocked on you": a question fires PreToolUse:AskUserQuestion the moment
    # it is asked; a permission or MCP elicitation dialog left unanswered for
    # 6 s fires a Notification of that type. (idle_prompt — a finished turn
    # sitting unanswered — is deliberately left out: the fall already said it.)
    PreToolUse = [
      {
        matcher = "AskUserQuestion";
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook waiting 2>/dev/null || true";
          }
        ];
      }
    ];
    Notification = [
      {
        matcher = "permission_prompt|elicitation_dialog";
        hooks = [
          {
            type = "command";
            command = "claudeos-agent-hook waiting 2>/dev/null || true";
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
    # stdenv.hostPlatform.system, not pkgs.system: the latter is a deprecated
    # alias that warns on every eval.
    inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default
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

  # Same seed philosophy, per HOOK: each ClaudeOS hook (event + matcher +
  # command) is merged into the live file once, the first activation that
  # knows it, and recorded in a stamp file. A hook added to agentHooks later
  # therefore still reaches machines whose settings.json already has hooks
  # (the old whole-key seed skipped them — the waiting twinkle never fired,
  # 2026-10-28), while one the user deletes stays deleted and their own hooks
  # are never touched: the live file keeps owning it (two-ring rule).
  # Tolerant of malformed JSON: a failed merge must never abort the whole HM
  # activation, and leaves the stamp alone so the next one retries.
  home.activation.seedClaudeHooks = lib.hm.dag.entryAfter [ "seedClaudeConfig" ] ''
    s="$HOME/.claude/settings.json"
    stamp="$HOME/.claude/claudeos-seeded-hooks"
    [ -e "$stamp" ] || : > "$stamp"
    # Retire the marker hooks this seed planted before 2026-11-08 (begin /
    # refresh / end): the per-hook seed never removes anything, so the live
    # file keeps them until something does. Only stanzas whose command is
    # exactly ours go; a user hook on the same event stays. An event left
    # with no stanzas is dropped so Claude Code sees no empty list.
    if [ -e "$s" ] && ${pkgs.jq}/bin/jq -e '
        [.hooks // {} | .[][]? | .hooks[]? | .command // ""]
        | any(test("^claudeos-agent-hook (begin|refresh|end) "))' "$s" >/dev/null 2>&1; then
      if ${pkgs.jq}/bin/jq '
          .hooks |= (to_entries
            | map(.value |= (map(.hooks |= map(select((.command // "") | test("^claudeos-agent-hook (begin|refresh|end) ") | not)))
                              | map(select(.hooks | length > 0))))
            | map(select(.value | length > 0))
            | from_entries)' "$s" > "$s.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$s.tmp" "$s"
      else
        rm -f "$s.tmp"
      fi
    fi
    if [ -e "$s" ]; then
      if ${pkgs.jq}/bin/jq --slurpfile h ${agentHooksJson} --rawfile seen "$stamp" '
          ($seen | split("\n")) as $seen
          | [$h[0] | to_entries[] | .key as $e | .value[] | (.matcher // "") as $m
              | .hooks[] | {e: $e, m: $m, h: ., k: "\($e)\t\($m)\t\(.command)"}] as $want
          | reduce ($want[] | select(.k as $k | $seen | index($k) | not)) as $x (.;
              if any((.hooks[$x.e] // [])[]; (.matcher // "") == $x.m and any(.hooks[]?; .command == $x.h.command))
              then .
              else .hooks[$x.e] = (.hooks[$x.e] // []) + [(if $x.m == "" then {} else {matcher: $x.m} end) + {hooks: [$x.h]}]
              end)' "$s" > "$s.tmp" 2>/dev/null \
        && ${pkgs.jq}/bin/jq -r --rawfile seen "$stamp" \
          '[($seen | split("\n")[] | select(. != "")), (to_entries[] | .key as $e | .value[] | (.matcher // "") as $m | .hooks[] | "\($e)\t\($m)\t\(.command)")] | unique[]' \
          ${agentHooksJson} > "$stamp.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$s.tmp" "$s"
        $DRY_RUN_CMD mv "$stamp.tmp" "$stamp"
      else
        rm -f "$s.tmp" "$stamp.tmp"
        echo "claudeos: could not seed agent-pulse hooks into $s (malformed JSON?)" >&2
      fi
    fi
  '';
}
