{ lib, ... }:

# Claude Code-inspired prompt — colors use ANSI names (orange, red, cyan, etc.)
# which map to the Stylix-themed terminal palette. Warm, minimal, clean.
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
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
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

      # Nix shell in sage
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
        style = "cyan";
        impure_msg = "impure";
        pure_msg = "pure";
      };

      # Command duration — dim, stays out of the way
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "bright-black";
      };

      # Username — warm sand, only when relevant
      username = {
        show_always = false;
        format = "[$user]($style) ";
        style_user = "yellow";
        style_root = "bold red";
      };

      # Hostname — only over SSH
      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = "yellow";
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
