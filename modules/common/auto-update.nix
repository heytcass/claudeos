# modules/common/auto-update.nix — Weekly unattended NixOS flake updates with Claude review.
#
# Flow: nix flake update → build test → Claude-reviewed changelog → commit & push → notify
# On failure: Claude diagnoses the error, reverts flake.lock, notifies user.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.autoUpdate;

  updateScript = pkgs.writeShellScript "claudeos-auto-update" ''
        export PATH="${
          pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.git
            pkgs.nix
            pkgs.gnugrep
            pkgs.gawk
            pkgs.diffutils
            pkgs.hostname
            pkgs.libnotify
          ]
        }:/run/current-system/sw/bin:$PATH"

        CLAUDEOS_DIR="$HOME/.config/claudeos"
        CLAUDE_BIN="$HOME/.local/bin/claude"
        HOST=$(hostname) || exit 1

        cd "$CLAUDEOS_DIR" || exit 1

        # Stash uncommitted work
        stashed=false
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
          git stash push -m "auto-update: pre-update stash $(date -Iseconds)" && stashed=true
        fi

        cleanup() {
          if $stashed; then
            git stash pop 2>/dev/null || true
          fi
        }

        # Sync with origin first so we never update/commit on stale history
        if ! git pull --rebase 2>&1; then
          notify-send --app-name=ClaudeOS --urgency=critical \
            "Update Skipped" "git pull --rebase failed — resolve repo state manually."
          cleanup
          exit 1
        fi

        # Update flake inputs
        if ! nix flake update 2>&1; then
          notify-send --app-name=ClaudeOS --urgency=critical \
            "Update Failed" "nix flake update failed. Check network connectivity."
          cleanup
          exit 1
        fi

        # Test build
        build_output=$(nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" 2>&1)
        build_status=$?

        if [[ $build_status -eq 0 ]]; then
          # Success — generate changelog
          diff_output=$(nix store diff-closures /run/current-system ./result 2>&1 || true)

          changelog=""
          if [[ -x "$CLAUDE_BIN" ]]; then
            changelog=$("$CLAUDE_BIN" -p "Summarize this NixOS package update diff. List notable version bumps and flag potentially breaking changes. 2-3 sentences max. No markdown.

    $diff_output" --model haiku 2>/dev/null) || changelog=""
          fi

          [[ -z "$changelog" ]] && changelog="Flake inputs updated ($(date -I))"

          # Name the generation: short slug from the changelog → boot-menu label
          slug=""
          if [[ -x "$CLAUDE_BIN" ]]; then
            slug=$("$CLAUDE_BIN" -p "Turn this update summary into a slug of 2-4 lowercase words joined by hyphens, only [a-z0-9-], max 40 chars, no explanation:

    $changelog" --model haiku 2>/dev/null) || slug=""
            slug=$(echo "$slug" | tr -c 'a-zA-Z0-9:_.-' '-' | cut -c1-40)
          fi
          [[ -z "$slug" || "$slug" =~ ^-*$ ]] && slug="flake-update-$(date +%m%d)"
          echo "$slug" > generation-label

          # Commit and push (retry once after rebase in case origin moved mid-run)
          git add flake.lock generation-label
          git commit -m "chore: weekly flake update — $changelog"
          if ! git push; then
            git pull --rebase && git push || notify-send --app-name=ClaudeOS --urgency=critical \
              "Push Failed" "flake.lock committed locally but not pushed — push manually."
          fi

          notify-send --app-name=ClaudeOS \
            "Flake Updated" "$changelog"

          ${lib.optionalString cfg.autoApply ''
            if sudo nixos-rebuild switch --flake "$CLAUDEOS_DIR#$HOST" 2>&1; then
              notify-send --app-name=ClaudeOS \
                "System Rebuilt" "Auto-update applied successfully."
            else
              notify-send --app-name=ClaudeOS --urgency=critical \
                "Rebuild Failed" "Flake updated but rebuild failed. Run 'rebuild' manually."
            fi
          ''}
        else
          # Build failed — diagnose and revert
          diagnosis=""
          if [[ -x "$CLAUDE_BIN" ]]; then
            diagnosis=$("$CLAUDE_BIN" -p "This NixOS build failed after flake update. Diagnose the issue briefly and suggest a fix. No markdown.

    $build_output" --model sonnet 2>/dev/null) || diagnosis=""
          fi

          [[ -z "$diagnosis" ]] && diagnosis="Build failed after flake update. Run 'nix log' to see details."

          notify-send --app-name=ClaudeOS --urgency=critical \
            "Update Build Failed" "$diagnosis"

          # Revert flake.lock
          git checkout flake.lock
        fi

        cleanup
        rm -f ./result
  '';
in
{
  options.claude-os.autoUpdate = {
    enable = lib.mkEnableOption "weekly automated NixOS flake updates with Claude review";

    autoApply = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to automatically run nixos-rebuild switch after a successful update build.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sat *-*-* 03:00:00";
      description = "Systemd calendar expression for when to run updates.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.claudeos-auto-update = {
      description = "ClaudeOS automated flake update with Claude review";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString updateScript;
        TimeoutStartSec = "30min";
      };
    };

    systemd.user.timers.claudeos-auto-update = {
      description = "Weekly ClaudeOS flake update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
