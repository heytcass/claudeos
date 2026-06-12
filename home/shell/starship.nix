{ lib, ... }:

# Claude Code-inspired prompt — colors use ANSI names (orange, red, cyan, etc.)
# which map to the Stylix-themed terminal palette. Warm, minimal, clean.
#
# The right side is ClaudeOS reporting in: the *named* generation you're booted
# into (see modules/common/generation-label.nix), a red pip that only exists
# when systemd has failed units, and Claude's ✳ when a Claude Code session is
# the one driving the shell. The fish transient prompt collapses all of it
# to ❯ in scrollback.
let
  # Counts failed system+user units — shared by custom.degraded's `when`
  # (starship runs it to decide visibility) and `command` (the displayed count)
  failedUnitsCmd = "(systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain) 2>/dev/null | wc -l";
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      # Two-line: context on top, input character below
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "$nix_shell"
        "$jobs"
        "$line_break"
        "$character"
      ];

      # System state lives on the right, out of the typing path
      right_format = lib.concatStrings [
        "$status"
        "$cmd_duration"
        "\${custom.claude}"
        "\${custom.degraded}"
        "$sudo"
        "$battery"
        "\${custom.generation}"
      ];

      # Terracotta prompt character — the Claude signature
      character = {
        success_symbol = "[❯](orange)";
        error_symbol = "[❯](red)";
      };

      # Directory in warm off-white — clean, not shouty
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "white";
        format = "[$path]($style) ";
      };

      # Git branch in terracotta accent
      git_branch = {
        symbol = " ";
        style = "orange";
        format = "[$symbol$branch]($style) ";
      };

      # Git status — terracotta for dirty, olive for staged
      git_status = {
        style = "red";
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "= ";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "*\${count}";
        modified = "!\${count}";
        staged = "[+\${count}](green)";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };

      # Line-level diff size — the working tree narrates itself
      git_metrics = {
        disabled = false;
        format = "([+$added](green)[-$deleted](red) )";
      };

      # Nix shell in sage
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
        style = "cyan";
        impure_msg = "impure";
        pure_msg = "pure";
      };

      # Background jobs — easy to forget, cheap to show
      jobs = {
        symbol = "✦";
        format = "[$symbol$number]($style) ";
        style = "cyan";
      };

      # Non-zero exit code, terse, before duration
      status = {
        disabled = false;
        format = "[$status]($style) ";
        style = "red";
      };

      # Command duration — dim, stays out of the way
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "bright-black";
      };

      # Padlock when sudo credentials are cached — you are holding root
      sudo = {
        disabled = false;
        symbol = "🔓";
        format = "[$symbol]($style) ";
        style = "yellow";
      };

      # Battery only when it actually matters
      battery = {
        format = "[$symbol$percentage]($style) ";
        display = [
          {
            threshold = 20;
            style = "red";
          }
        ];
      };

      # ✳ — a Claude Code session is driving this shell
      custom.claude = {
        when = ''test -n "$CLAUDECODE"'';
        format = "[✳](orange) ";
        description = "Claude is at the keyboard";
      };

      # Red pip + count when systemd (system or user) has failed units.
      # Invisible on a healthy system — its absence is the feature.
      custom.degraded = {
        when = ''test "$( ${failedUnitsCmd})" -gt 0'';
        command = failedUnitsCmd;
        format = "[● $output failed](red) ";
        description = "systemd failed units";
      };

      # The booted generation's name (boot menu, snapshots, and prompt all
      # share one Claude-written slug). Only shows when a label exists.
      custom.generation = {
        when = ''grep -q "^[a-z]" /run/current-system/nixos-version 2>/dev/null'';
        command = ''sed "s/-[0-9].*//" /run/current-system/nixos-version'';
        symbol = "❄ ";
        format = "[$symbol$output]($style)";
        style = "bright-black";
        description = "named NixOS generation";
      };

      # Keep prompt fast — disable language modules
      nodejs.disabled = true;
      python.disabled = true;
      rust.disabled = true;
      golang.disabled = true;
      java.disabled = true;
      ruby.disabled = true;
      php.disabled = true;
    };
  };
}
