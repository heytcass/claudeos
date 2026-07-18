# modules/common/self-heal.nix — the OS files its own fix PRs.
#
# A systemd user template (claude-heal@.service) is attached via OnFailure=
# to opted-in units. On failure, a headless Claude agent session receives the
# unit's journal + systemctl state, investigates the owning module in the
# claudeos repo, and — if the failure is config-rooted — fixes it on a
# heal/* branch, validates with a dry-run build, and opens a PR.
# It never touches main directly.
#
# Approval gate — trust ladder, rung 2 (see docs/PHILOSOPHY.md, "The
# constitution"). This agent used to require a human merge for every fix.
# It no longer does, but only for the narrowest possible class of change.
# `.github/workflows/heal-automerge.yml` squash-merges a heal/* PR by itself
# when ALL of these hold, and holds it for a human otherwise:
#
#   - CI green on that exact SHA (treefmt/statix/deadnix + dry-run eval of
#     every host + one real toplevel build)
#   - the diff touches EXACTLY ONE file under modules/ or home/, *.nix
#   - never flake.nix, flake.lock, .sops.yaml, secrets/, .github/, .claude/
#   - <= 40 changed lines
#   - a separate Claude machine-review returns `VERDICT: APPROVE`
#   - the PR carries no `heal-hold` label
#
# `heal-hold` is the escape hatch: label any heal PR with it and the gate
# stands down. The gate cannot edit itself (.github/ is a protected path, and
# workflow_run always runs main's copy), and anything it merges is reversible
# — `git revert` the squash commit, or boot the previous generation.
#
# Cost profile: event-driven (unit failures only), per-unit 6h cooldown,
# sonnet-class model, runs on the Claude subscription. The merge gate adds one
# more sonnet call per heal PR.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.selfHeal;

  # The default watched units only exist behind their feature flags. Attaching
  # OnFailure= to a disabled one would synthesize a phantom user service
  # containing nothing but the handler — filter those out. Units this map
  # doesn't know about are watched unconditionally (the user declared them).
  unitEnabled = {
    "claudeos-auto-update" = config.claude-os.autoUpdate.enable;
    "claudeos-journal-diary" = config.claude-os.monitor.enable && config.claude-os.monitor.journalDiary;
  };
  watchedUnits = lib.filter (u: unitEnabled.${u} or true) cfg.units;

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

      # The whole point is a pushed branch + PR — don't spend a 20-minute
      # agent session that cannot deliver one. Headless runs (lingering, no
      # graphical session) need the sops automation token; in-session runs
      # can use the keyring.
      claudeos_export_gh_token
      if ! gh auth token >/dev/null 2>&1; then
        claudeos_notify \
          "Self-Heal Skipped: $UNIT" "No GitHub credential in this context (keyring locked, no sops automation token) — cannot open a PR."
        exit 0
      fi

      # Per-unit cooldown (6h) — a crash-looping unit must not fan out agents
      COOLDOWN_FILE="$CACHE_DIR/cooldown-$(systemd-escape "$UNIT")"
      claudeos_cooldown_ok "$COOLDOWN_FILE" 21600 || exit 0
      touch "$COOLDOWN_FILE"

      # Tell the bar's island what we're up to for the duration of the run.
      claudeos_agent_begin "healing ''${UNIT%.service}"

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
      4. Your final output: the PR URL, or SKIP: <reason>.

      A PR that changes exactly one *.nix file under modules/ or home/, by 40 lines or fewer, touching none of flake.nix / flake.lock / .sops.yaml / secrets/ / .github/ / .claude/, may be auto-merged once CI is green and a machine review approves it (trust ladder rung 2 — see the header of modules/common/self-heal.nix). Prefer the minimal, single-file fix when that IS the correct fix. Never contort a fix to fit the window: if the right change spans several files or exceeds 40 lines, make the right change and let a human review it. Widening a diff to dodge review, or narrowing one to court auto-merge, are the same failure."

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
      # The Jasper lane (claudeos-jasper) is deliberately NOT here: it's a
      # oneshot that can fail on a transient curl/gcalcli hiccup, which is not
      # config-rooted and must not spawn a heal PR.
      default = [
        "claudeos-auto-update"
        "claudeos-journal-diary"
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
      (lib.genAttrs watchedUnits (_: {
        unitConfig.OnFailure = [ "claude-heal@%n.service" ];
      }))
    ];
  };
}
