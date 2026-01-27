{ config, lib, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      # Clean, single-line format
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

      # Prompt character
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      # Directory display
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
        format = "[$path]($style) ";
      };

      # Git branch
      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "[$symbol$branch]($style) ";
      };

      # Git status
      git_status = {
        style = "bold red";
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "🏳 ";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "$\${count}";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };

      # Nix shell indicator
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
        style = "bold blue";
        impure_msg = "impure";
        pure_msg = "pure";
      };

      # Command duration (only show if > 2s)
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "bold yellow";
      };

      # Username (only show if not default user)
      username = {
        show_always = false;
        format = "[$user]($style) ";
        style_user = "bold green";
        style_root = "bold red";
      };

      # Hostname (only show if SSH)
      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = "bold green";
      };

      # Disable language-specific modules for faster prompt
      # Enable these if you want language version detection
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
