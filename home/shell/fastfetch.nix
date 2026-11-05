{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = config.lib.stylix.colors;

  # The Claude spark, recoloured from the asset's alpha onto base0D (the same
  # trick and the same token as the Plymouth splash, so boot and terminal
  # draw one spark). No hex here: the colour comes from Stylix.
  spark = pkgs.runCommand "claudeos-fastfetch-spark.png" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } "magick ${../../assets/claude-logo.png} -fill '${c.withHashtag.base0D}' -colorize 100 $out";

  # Shared prelude for the state lines: a compact "3h ago" formatter.
  ago = ''
    ago() {
      s=$(( $(date +%s) - $1 ))
      if   [ "$s" -lt 3600 ];  then echo "$(( s / 60 ))m ago"
      elif [ "$s" -lt 86400 ]; then echo "$(( s / 3600 ))h ago"
      else                          echo "$(( s / 86400 ))d ago"
      fi
    }
  '';

  # Each state line is its own script so writeShellApplication shellchecks it
  # at build time (rung 5) instead of failing silently inside a JSON string.
  stateLine =
    name: text:
    lib.getExe (
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
        text = ago + text;
      }
    );

  # The booted generation's Claude-written slug (generation-label.nix) and how
  # long since it was switched to. nixos-version is "<slug>-<release>"; an
  # unlabelled build is just "<release>".
  generation = stateLine "claudeos-fetch-generation" ''
    v=$(cat /run/current-system/nixos-version)
    slug=''${v%-[0-9][0-9].[0-9][0-9].*}
    [ "$slug" = "$v" ] && slug="unnamed ($v)"
    echo "$slug · switched $(ago "$(stat -c %Y /run/current-system)")"
  '';

  # Failed systemd units, system and user — the prompt's red pip, spelled out.
  health = stateLine "claudeos-fetch-health" ''
    failed=$( { systemctl --failed --no-legend --plain
                systemctl --user --failed --no-legend --plain; } 2>/dev/null \
              | cut -d' ' -f1 | sed 's/^●//' | grep -v '^$' || true)
    if [ -z "$failed" ]; then
      echo "all units healthy"
    else
      echo "$(echo "$failed" | wc -l) failed: $(echo "$failed" | tr '\n' ' ')"
    fi
  '';

  # The weekly auto-update lane (modules/common/auto-update.nix): its last
  # success, or its last revert if that is more recent.
  autoUpdate = stateLine "claudeos-fetch-auto-update" ''
    d="''${XDG_STATE_HOME:-$HOME/.local/state}/claudeos"
    ok=0; rev=0
    [ -f "$d/last-update" ] && ok=$(date -d "$(cat "$d/last-update")" +%s)
    [ -f "$d/last-update-revert" ] && rev=$(date -d "$(cat "$d/last-update-revert")" +%s)
    if [ "$ok" -eq 0 ] && [ "$rev" -eq 0 ]; then
      echo "never run"
    elif [ "$rev" -gt "$ok" ]; then
      echo "reverted $(ago "$rev")"
    else
      echo "updated $(ago "$ok")"
    fi
  '';

  command = key: text: {
    type = "command";
    inherit key text;
  };
in
{
  # fastfetch — the on-demand system fetch. Deliberately NOT run from fish's
  # interactiveShellInit: the first shell shows the daily brief and nothing
  # else (proactivity doctrine — macchina's MOTD was dropped for being a
  # spec-sheet feed). Type `fastfetch` when you want it.
  #
  # Below the spec sheet, ClaudeOS reports on itself: the named generation,
  # unit health, and the auto-update lane. Key colours are ANSI names, so the
  # Stylix-themed terminal palette decides what they look like. Replaces the
  # unmaintained macchina (docs/plans/2026-06-12-tool-rethink.md).
  programs.fastfetch = {
    enable = true;
    settings = {
      # kitty-direct hands Ghostty the file path; terminals without the kitty
      # graphics protocol (SSH, the Claude Code tool shell) show no logo.
      logo = {
        type = "kitty-direct";
        source = "${spark}";
        width = 28;
        height = 14;
        padding.right = 2;
      };
      display = {
        separator = "  ";
        color = {
          keys = "blue";
          title = "magenta";
        };
      };
      modules = [
        "title"
        "os"
        "host"
        "kernel"
        "uptime"
        "shell"
        "wm"
        "terminal"
        "cpu"
        "memory"
        "disk"
        "break"
        (command "Generation" generation)
        (command "Health" health)
        (command "Auto-update" autoUpdate)
      ];
    };
  };
}
