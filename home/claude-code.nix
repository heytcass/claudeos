# home/claude-code.nix — Declarative Claude Code configuration via home-manager.
# Generates ~/.claude/settings.json and ~/.claude/.mcp.json from Nix expressions.
{ pkgs, ... }:

let
  # Statusline script — reads Stylix palette for themed Claude Code status bar
  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
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

  # Claude Code global settings
  # Plugins: minimal global set — opt-in per project via .claude/settings.local.json
  # e.g. { "enabledPlugins": { "superpowers@claude-plugins-official": true } }
  claudeSettings = {
    statusLine = {
      type = "command";
      command = "bash ${statuslineScript}";
    };
    enabledPlugins = {
      "github@claude-plugins-official" = true;
      "learning-output-style@claude-plugins-official" = true;
    };
    skipDangerousModePermissionPrompt = true;
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
  };

  # MCP server configuration
  mcpConfig = {
    mcpServers = {
      nixos = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
          "--"
        ];
      };
      system-health = {
        command = "mcp-system-health";
        args = [ ];
      };
    };
  };
in
{
  # Generate ~/.claude/settings.json
  home.file.".claude/settings.json" = {
    text = builtins.toJSON claudeSettings;
    force = true;
  };

  # Generate ~/.claude/.mcp.json
  home.file.".claude/.mcp.json" = {
    text = builtins.toJSON mcpConfig;
    force = true;
  };
}
