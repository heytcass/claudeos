# modules/common/self-heal.nix — the OS files its own fix PRs.
#
# A systemd user template (claude-heal@.service) is attached via OnFailure=
# to opted-in units. On failure, a headless Claude agent session receives the
# unit's journal + systemctl state, investigates the owning module in the
# claudeos repo, and — if the failure is config-rooted — fixes it on a
# heal/* branch, validates with a dry-run build, and opens a PR for review.
# It never touches main; the human merge is the approval gate.
#
# Cost profile: event-driven (unit failures only), per-unit 6h cooldown,
# sonnet-class model, runs on the Claude subscription.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.selfHeal;

  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  healScript = claudeLib.mkClaudeScript {
    name = "claude-heal";
    runtimeInputs = [ pkgs.nix ];
    text = ''
      UNIT="$1"
      CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-heal"
      mkdir -p "$CACHE_DIR"

      [[ -x "$CLAUDE_BIN" ]] || exit 0
      [[ -d "$CLAUDEOS_DIR/.git" ]] || exit 0

      # Per-unit cooldown (6h) — a crash-looping unit must not fan out agents
      COOLDOWN_FILE="$CACHE_DIR/cooldown-$(systemd-escape "$UNIT")"
      if [[ -f "$COOLDOWN_FILE" ]]; then
        last=$(stat -c %Y "$COOLDOWN_FILE" 2>/dev/null || echo 0)
        (( $(date +%s) - last < 21600 )) && exit 0
      fi
      touch "$COOLDOWN_FILE"

      journal=$(journalctl --user -u "$UNIT" -n 200 --no-pager 2>/dev/null)
      [[ -z "$journal" ]] && journal=$(journalctl -u "$UNIT" -n 200 --no-pager 2>/dev/null)
      state=$(systemctl --user show "$UNIT" \
        --property=Result,ExecMainStatus,NRestarts,InvocationID 2>/dev/null)

      branch="heal/$(systemd-escape "$UNIT" | tr -c 'a-zA-Z0-9-' '-' | head -c 30)$(date +%m%d-%H%M)"

      cd "$CLAUDEOS_DIR" || exit 1

      prompt="You are the ClaudeOS self-heal agent. The systemd user unit '$UNIT' on host $(hostname) just FAILED.

      Unit state:
      $state

      Last 200 journal lines:
      $journal

      Your job:
      1. Decide whether this failure is rooted in the NixOS configuration in this repo (the unit is defined somewhere under modules/ or home/). If it is transient (network blip, the machine was suspending, an external service was down) or you cannot determine a config-level cause, output exactly SKIP: <one-line reason> and STOP — do not edit anything.
      2. If config-rooted: find the owning module (grep for the unit name), make the minimal fix, and validate it with: nix build .#nixosConfigurations.\$(hostname).config.system.build.toplevel --dry-run
      3. Work ONLY on a new branch named $branch — never commit to main. Stage, commit (conventional message, mention the unit), push the branch, then open a PR with: gh pr create --base main --fill
      4. Your final output: the PR URL, or SKIP: <reason>."

      text=$(claude_headless sonnet "$prompt" \
        --allowedTools 'Read,Grep,Glob,Edit,Bash(git status*),Bash(git diff*),Bash(git log*),Bash(git checkout -b *),Bash(git add *),Bash(git commit *),Bash(git push *),Bash(gh pr create*),Bash(nix build*--dry-run*),Bash(journalctl*),Bash(systemctl status*),Bash(systemctl --user status*),Bash(hostname)')

      if [[ -z "$text" ]]; then
        claudeos_notify --urgency=critical \
          "Self-Heal" "$UNIT failed; heal agent produced no result. Check journalctl --user -u claude-heal@*."
      elif [[ "$text" == SKIP:* ]]; then
        claudeos_notify \
          "Self-Heal: $UNIT" "Failure judged transient — no fix attempted. ''${text#SKIP:}"
      else
        claudeos_notify --urgency=critical \
          "Self-Heal: $UNIT" "Fix proposed: $text"
      fi
    '';
  };
in
{
  options.claude-os.selfHeal = {
    enable = lib.mkEnableOption "Claude self-heal agent that opens fix PRs when watched units fail";

    units = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "claudeos-auto-update"
        "claudeos-journal-diary"
        "jasper-companion"
      ];
      description = ''
        systemd user units that get OnFailure=claude-heal@%n.service attached.
        Never list claude-heal@ itself or claudeos-health-check (it has its own
        OnFailure handler) — loop prevention.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = lib.mkMerge [
      {
        "claude-heal@" = {
          description = "ClaudeOS self-heal agent for %i";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${healScript} %i";
            TimeoutStartSec = "20min";
            PrivateTmp = true;
            NoNewPrivileges = true;
            SyslogIdentifier = "claude-heal";
          };
        };
      }
      (lib.genAttrs cfg.units (_: {
        unitConfig.OnFailure = [ "claude-heal@%n.service" ];
      }))
    ];
  };
}
