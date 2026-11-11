# modules/common/desktop-update.nix — follow Claude Desktop releases within the hour.
#
# The app's "Update available" banner means the packaging flake
# (the claude-desktop-linux input) has usually already repinned the new
# release: its own workflow polls Anthropic's apt index hourly and merges
# behind a build gate. What lagged was this repo's flake.lock, which only
# moved on the weekly auto-update lane (Sat 03:00) or the Dependabot
# fallback (Mon), so a release could sit for a week with the banner up.
#
# Flow: compare the input's upstream head with the rev locked on origin/main
# → if the packaged VERSION differs, `nix flake update claude-desktop-linux`
# in a lane worktree → commit flake.lock → claudeos-land (PR, CI's lock-gate:
# full gti build + VM boot, squash-merge, switch) → card.
#
# Deliberate limits:
#   - Only this one input moves. A lock diff that touches any other node
#     aborts the run; nixpkgs and friends stay with the weekly lane and its
#     VM gate.
#   - Version, not rev: the packaging repo's main also moves for workflow and
#     README edits, and each lock bump costs a lock-gate run.
#   - A rev that failed to land is remembered and not retried hourly; a newer
#     upstream rev (the fix) clears the way on its own.
#   - The running app is never restarted (home/claude-desktop.nix,
#     X-RestartIfChanged=false): it hosts every Claude Code session. The new
#     build starts the next time the app is quit and reopened.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.desktopUpdate;

  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  updateScript = claudeLib.mkClaudeScriptBin {
    name = "claudeos-desktop-update";
    runtimeInputs = [
      pkgs.nix
      pkgs.gh
      pkgs.check-jsonschema # validator for the bar card (claudeos_lane_card)
    ];
    text = ''
      # Usage: claudeos-desktop-update [--dry-run | --retry]
      #   --dry-run  report what would happen; change nothing
      #   --retry    forget a remembered failed attempt, then run
      CLAUDEOS_LANE=desktop-update
      INPUT=claude-desktop-linux
      HOST=$(hostname) || exit 1
      failed_marker="$STATE_DIR/desktop-update-failed-rev"

      dry=false
      case "''${1:-}" in
        --dry-run) dry=true ;;
        --retry) rm -f "$failed_marker" ;;
      esac

      # A wake from suspend can fire the timer before the network is back.
      # Nothing is lost by skipping: the next hourly run covers it.
      claudeos_wait_for_network 120 || { echo "No network; skipping this run."; exit 0; }

      # origin/main, not the shared checkout's working file: main is what
      # hosts deploy, and a fetch moves no HEAD or index there.
      git -C "$CLAUDEOS_DIR" fetch -q origin main ||
        { echo "Could not fetch origin; skipping this run."; exit 0; }
      read -r owner repo locked_rev < <(
        git -C "$CLAUDEOS_DIR" show origin/main:flake.lock |
          jq -r --arg i "$INPUT" '.nodes[$i].locked | "\(.owner) \(.repo) \(.rev)"'
      )
      if [[ -z "''${locked_rev:-}" || "$locked_rev" == null ]]; then
        echo "flake.lock has no github-locked '$INPUT' input; nothing to follow." >&2
        exit 1
      fi

      upstream_rev=$(git ls-remote "https://github.com/$owner/$repo" HEAD 2>/dev/null | cut -f1)
      [[ -n "$upstream_rev" ]] || { echo "Could not read $owner/$repo's head; skipping this run."; exit 0; }
      if [[ "$upstream_rev" == "$locked_rev" ]]; then
        echo "Claude Desktop input is current (''${locked_rev:0:8})."
        exit 0
      fi

      version_at() {
        curl -fsSL --max-time 20 "https://raw.githubusercontent.com/$owner/$repo/$1/pkgs/sources.json" |
          jq -r '.version // empty'
      }
      old=$(version_at "$locked_rev")
      new=$(version_at "$upstream_rev")
      [[ -n "$new" ]] || { echo "Could not read the upstream version; skipping this run."; exit 0; }
      if [[ "$new" == "$old" ]]; then
        echo "$owner/$repo moved (''${upstream_rev:0:8}) but still packages $new; leaving the lock alone."
        exit 0
      fi
      if [[ -f "$failed_marker" && "$(<"$failed_marker")" == "$upstream_rev" ]]; then
        echo "Claude Desktop $new (''${upstream_rev:0:8}) already failed to land; not retrying until upstream moves. Force with --retry."
        exit 0
      fi

      if $dry; then
        echo "Would update Claude Desktop ''${old:-unknown} → $new ($owner/$repo@''${upstream_rev:0:8})."
        exit 0
      fi

      claudeos_export_gh_token
      gh auth token >/dev/null 2>&1 ||
        { echo "No GitHub credential in this context; skipping this run."; exit 0; }

      mkdir -p "$STATE_DIR"
      claudeos_agent_begin "updating Claude Desktop → $new"
      branch="desktop-update/$new"
      pr_url=""

      # claudeos-land sweeps landed lane worktrees itself, so after a
      # successful land this one is usually already gone.
      drop_worktree() {
        cd "$CLAUDEOS_DIR" || return 0
        if [[ -d "''${LANE_WORKTREE:-}" ]]; then claudeos_lane_worktree_drop --delete-branch; fi
        return 0
      }

      # Every handled failure ends here: remember the rev so the next hourly
      # run doesn't repeat a 30-minute CI run for the same answer, leave a
      # card, and exit 0. A failed unit would be re-alerted by the health
      # check every 15 minutes; the card is the durable record instead.
      fail() {
        echo "desktop-update: $1" >&2
        echo "$upstream_rev" >"$failed_marker"
        claudeos_notify --urgency=critical "Claude Desktop update failed" "$1"
        claudeos_lane_card desktop-update "Claude Desktop $new: update failed" "⬆️" critical \
          "$1"$'\n\n'"Still on ''${old:-the previous version}. Not retried until the packaging repo moves again; force with: claudeos-desktop-update --retry" \
          "$pr_url" "Open PR"
        claudeos_agent_done "Claude Desktop $new: $1" "$pr_url"
        drop_worktree
        exit 0
      }

      # Leftovers from a run that was killed mid-flight would block the
      # worktree add below.
      stale="$STATE_DIR/worktrees/''${branch//\//-}"
      [[ -d "$stale" ]] && git -C "$CLAUDEOS_DIR" worktree remove --force "$stale" 2>/dev/null
      git -C "$CLAUDEOS_DIR" worktree prune
      git -C "$CLAUDEOS_DIR" branch -q -D "$branch" 2>/dev/null

      claudeos_lane_worktree "$branch" || fail "Could not create a worktree for $branch."

      nix flake update "$INPUT" 2>&1 || fail "nix flake update $INPUT failed."
      if git diff --quiet -- flake.lock; then
        echo "flake.lock already carries $new; nothing to do."
        drop_worktree
        exit 0
      fi

      # This lane moves one input. Anything else changing in the lock is the
      # weekly lane's job, behind its own gate.
      others() { jq -S --arg i "$INPUT" 'del(.nodes[$i])'; }
      if [[ "$(git show HEAD:flake.lock | others)" != "$(others <flake.lock)" ]]; then
        fail "The lock bump touched inputs other than $INPUT; refusing to land it."
      fi

      git commit -q -m "chore: update Claude Desktop to $new" \
        -m "Bumps the $INPUT input ''${old:-unknown} → $new ($owner/$repo@''${upstream_rev:0:8}). Opened by the desktop-update lane." \
        -- flake.lock || fail "Could not commit flake.lock."

      # claudeos-land: push, PR, wait for required CI (lock-gate builds gti
      # and boots it in a VM), squash-merge, fast-forward the shared
      # checkout, switch this host.
      land_log=$(mktemp)
      claudeos-land 2>&1 | tee "$land_log"
      land_rc=''${PIPESTATUS[0]}
      # The sweep may have removed the directory this shell stands in.
      cd "$CLAUDEOS_DIR" || exit 0
      pr_url=$(gh pr list --head "$branch" --state all --json url -q '.[0].url // empty' 2>/dev/null)

      if [[ $land_rc -ne 0 ]]; then
        reason=$(grep -m1 '^claudeos-land: ' "$land_log" | cut -c1-300)
        rm -f "$land_log"
        git -C "$CLAUDEOS_DIR" fetch -q origin main
        main_rev=$(git -C "$CLAUDEOS_DIR" show origin/main:flake.lock |
          jq -r --arg i "$INPUT" '.nodes[$i].locked.rev')
        if [[ "$main_rev" == "$upstream_rev" ]]; then
          # Merged, but this host did not switch. main is right, so there is
          # nothing to retry and no failed rev to remember: say what's left.
          claudeos_notify --urgency=critical "Claude Desktop $new merged, not applied" \
            "''${reason:-claudeos-land stopped after the merge.} Run 'rebuild'."
          claudeos_lane_card desktop-update "Claude Desktop $new: merged, not applied" "⬆️" critical \
            "''${reason:-claudeos-land stopped after the merge.}"$'\n\n'"main has the update; $HOST has not switched. Run 'rebuild'." \
            "$pr_url" "Open PR"
          claudeos_agent_done "Claude Desktop $new merged, not applied on $HOST" "$pr_url"
          drop_worktree
          exit 0
        fi
        fail "''${reason:-claudeos-land failed; see journalctl --user -u claudeos-desktop-update.}"
      fi
      rm -f "$land_log" "$failed_marker"

      claudeos_notify "Claude Desktop $new installed" \
        "Quit and reopen the app to start using it. Until then it keeps running ''${old:-the previous version}."
      claudeos_lane_card desktop-update "Claude Desktop $new ready" "⬆️" normal \
        "Updated ''${old:-the previous version} → $new and switched $HOST."$'\n\n'"The running app is left alone because it hosts your sessions. Quit and reopen it to start $new." \
        "$pr_url" "Open PR"
      claudeos_agent_done "Claude Desktop ''${old:-?} → $new" "$pr_url"
      drop_worktree
    '';
  };
in
{
  options.claude-os.desktopUpdate = {
    enable = lib.mkEnableOption "an hourly lane that bumps the Claude Desktop flake input when a new release is packaged, then lands and applies it";

    schedule = lib.mkOption {
      type = lib.types.str;
      # The packaging repo polls at :23 and its build-gated PR merges about
      # five minutes later; :40 picks a release up in the same hour.
      default = "*-*-* *:40:00";
      description = "Systemd calendar expression for when to check for a new packaged release.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # claudeos-land ends in `sudo -n nixos-rebuild switch`; the scoped
        # NOPASSWD rule it needs only exists under autoUpdate.autoApply.
        assertion = config.claude-os.autoUpdate.enable && config.claude-os.autoUpdate.autoApply;
        message = "claude-os.desktopUpdate needs claude-os.autoUpdate.enable and .autoApply: they provide the passwordless nixos-rebuild rule claudeos-land uses to switch from a timer.";
      }
    ];

    # On PATH too: `claudeos-desktop-update --dry-run` answers "is there a
    # newer build?" on demand, and a session can run it instead of waiting
    # for the timer.
    environment.systemPackages = [ updateScript ];

    systemd.user.services.claudeos-desktop-update = {
      description = "ClaudeOS Claude Desktop update lane";
      # The lane's land step switches the generation this unit belongs to;
      # a restart would SIGTERM it mid-switch (same hazard as
      # claudeos-auto-update). The next timer firing picks up a new script.
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe updateScript;
        # claudeos-land waits up to 90 min on required checks.
        TimeoutStartSec = "2h";
      };
    };

    systemd.user.timers.claudeos-desktop-update = {
      description = "Hourly check for a new Claude Desktop release";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = "5min";
      };
    };
  };
}
