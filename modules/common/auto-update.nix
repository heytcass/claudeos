# modules/common/auto-update.nix — Weekly unattended NixOS flake updates with Claude review.
#
# Flow: nix flake update → build test → VM smoke-test gate → Claude-reviewed
# changelog → commit & push → nixos-rebuild switch (autoApply) → notify
#
# The VM gate is what makes autoApply safe: the freshly built generation is
# booted headless in a throwaway QEMU VM (config.system.build.vm with a
# vmVariant that strips hardware-specific config) and must reach
# multi-user.target with zero failed units and display-manager.service active before the
# update may be committed, pushed, or applied. No usable /dev/kvm → the gate
# is skipped and the run degrades to the old build-only behavior (commit and
# push, never switch).
#
# On a build failure: Claude diagnoses the error, flake.lock is reverted, the
# user is notified. On a red VM run: flake.lock is reverted, the failing unit
# list is sent via notify-send, the VM serial log (including per-unit journal
# excerpts) is echoed into this unit's own journal, and the script exits
# non-zero — which fires OnFailure=claude-heal@claudeos-auto-update
# (modules/common/self-heal.nix), handing the excerpt to the self-heal agent.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.autoUpdate;

  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  updateScript = claudeLib.mkClaudeScript {
    name = "claudeos-auto-update";
    runtimeInputs = [
      pkgs.nix
      pkgs.diffutils
      pkgs.curl
      pkgs.check-jsonschema # validator for the bar card (claudeos_lane_card)
    ];
    text = ''
      HOST=$(hostname) || exit 1

      cd "$CLAUDEOS_DIR" || exit 1

      CLAUDEOS_LANE=auto-update

      # Persistent=true on the timer fires a missed weekly run immediately on
      # next boot, which can race the network coming up. Shared helper lives in
      # lib/claude-script.nix and carries the full explanation; 300s here
      # because an update that starts without git remotes is a wasted week.
      claudeos_wait_for_network 300 || true

      # Durable run breadcrumbs — a dead updater must be visible days later
      # (morning brief + health check read these), not just in a vanished
      # notification. last-update is only stamped on a fully successful run.
      mkdir -p "$STATE_DIR"
      date -Iseconds > "$STATE_DIR/last-update-attempt"

      claudeos_export_gh_token

      # Sync with origin first so we never update/commit on stale history.
      # --autostash (not a manual stash) keeps uncommitted work — e.g. the
      # journal diary's pending docs/known-issues.md edits — riding the
      # rebase; a conflict aborts the pull with the work restored intact.
      if ! git pull --rebase --autostash 2>&1; then
        claudeos_notify --urgency=critical \
          "Update Skipped" "git pull --rebase failed — resolve repo state manually."
        exit 1
      fi

      # Update flake inputs
      if ! nix flake update 2>&1; then
        claudeos_notify --urgency=critical \
          "Update Failed" "nix flake update failed. Check network connectivity."
        exit 1
      fi

      # Test build
      build_output=$(nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" 2>&1)
      build_status=$?

      if [[ $build_status -eq 0 ]]; then
        # --- VM smoke-test gate -------------------------------------------
        # "passed"   → commit, push, and (autoApply) switch
        # "skipped"  → no usable /dev/kvm: commit and push, never switch
        # "disabled" → vmTest = false: same degraded lane as "skipped"
        # "failed"   → revert flake.lock, notify, exit 1 → self-heal agent
        vm_gate="disabled"
        vm_log=""
        ${lib.optionalString cfg.vmTest ''
          vm_gate="skipped"
          if [[ -r /dev/kvm && -w /dev/kvm ]]; then
            vm_log=$(mktemp -t claudeos-vm-smoke.XXXXXX)
            if vm_build_output=$(nix build \
                ".#nixosConfigurations.$HOST.config.system.build.vm" \
                --out-link ./result-vm 2>&1); then
              # Boot the next generation headless. The in-VM claudeos-vm-smoke
              # service prints CLAUDEOS-SMOKE-PASS/-FAIL on the serial console
              # (captured here) and powers the VM off.
              timeout ${toString cfg.vmTestTimeout} \
                "./result-vm/bin/run-$HOST-vm" </dev/null >"$vm_log" 2>&1 || true
              if grep -q "CLAUDEOS-SMOKE-PASS" "$vm_log"; then
                vm_gate="passed"
              else
                vm_gate="failed"
              fi
            else
              vm_gate="failed"
              echo "VM build failed:" >"$vm_log"
              echo "$vm_build_output" >>"$vm_log"
            fi
          fi
        ''}

        if [[ "$vm_gate" == "failed" ]]; then
          fail_line=$(grep -m1 "CLAUDEOS-SMOKE-FAIL" "$vm_log" \
            || echo "CLAUDEOS-SMOKE-FAIL: VM never reported (timeout, boot hang, or VM build failure)")
          # Echo the serial log into our own journal — claude-heal@ reads the
          # last 200 lines of this unit's journal, so this hands the excerpt
          # to the self-heal agent.
          echo "=== VM smoke-test gate failed — update blocked ==="
          echo "$fail_line"
          echo "--- last 120 lines of VM serial console ---"
          tail -n 120 "$vm_log" || true
          claudeos_notify --urgency=critical \
            "Update Blocked: VM Smoke Test" "$fail_line"
          claudeos_lane_card auto-update "Update blocked: VM smoke test" "📦" critical \
            "$fail_line"$'\n\n'"flake.lock reverted; the self-heal agent has the serial-log excerpt."
          git checkout flake.lock
          date -Iseconds > "$STATE_DIR/last-update-revert"
          rm -f ./result ./result-vm "$vm_log"
          exit 1
        fi
        [[ -n "$vm_log" ]] && rm -f "$vm_log"
        # ------------------------------------------------------------------

        # Success — generate changelog
        diff_output=$(nix store diff-closures /run/current-system ./result 2>&1 || true)

        export CLAUDEOS_AGENT_ACTIVITY="summarizing the update"
        changelog=$(claude_text haiku "Summarize this NixOS package update diff. List notable version bumps and flag potentially breaking changes. 2-3 sentences max. No markdown.

      $diff_output")

        # CLI/API error text ("You've hit your monthly spend limit", "Not
        # logged in") must not become the commit message — or, via --local
        # below, the generation slug
        if echo "$changelog" | grep -qiE 'spend limit|usage limit|rate limit|not logged in|please run /login|api error|overloaded'; then
          changelog=""
        fi
        [[ -z "$changelog" ]] && changelog="Flake inputs updated ($(date -I))"

        # Name the generation (shared slug logic → boot-menu label).
        # --local: the changelog IS already a haiku summary — deriving the
        # slug from it locally avoids a second model call per run
        echo "$changelog" | claude-name-generation --local --fallback "flake-update-$(date +%m%d)" > /dev/null

        # Commit and push (retry once after rebase in case origin moved mid-run)
        git add flake.lock generation-label
        git commit -m "chore: weekly flake update — $changelog"
        if ! gh auth token >/dev/null 2>&1; then
          claudeos_notify --urgency=critical \
            "Push Skipped" "flake.lock committed locally — no GitHub credential in this context (keyring locked, no sops automation token). Push manually."
        elif ! git push; then
          git pull --rebase && git push || claudeos_notify --urgency=critical \
            "Push Failed" "flake.lock committed locally but not pushed — push manually."
        fi

        date -Iseconds > "$STATE_DIR/last-update"
        claudeos_agent_done "flake updated: $changelog"
        claudeos_notify "Flake Updated" "$changelog"
        # Durable record (Phase 4). Emitted under the stable "auto-update" id,
        # so the autoApply branch below can REPLACE it with the applied state
        # rather than stack a second card.
        claudeos_lane_card auto-update "Flake updated" "📦" normal \
          "$changelog"$'\n\n'"VM gate: $vm_gate — built and pushed; apply with 'rebuild'."

        ${lib.optionalString cfg.autoApply ''
          if [[ "$vm_gate" == "passed" ]]; then
            # /run/wrappers/bin/sudo explicitly: the preamble PATH (and a
            # systemd user unit's inherited PATH) resolves plain `sudo` to the
            # non-setuid store binary, which cannot elevate ("sudo must be
            # owned by uid 0"). Interactive shells never hit this — wrappers
            # come first there — so it only bites in unit context.
            # `boot`, deliberately NOT `switch`. A live switch activates the new
            # generation under a running graphical session: long-lived processes
            # keep their old /nix/store paths mapped, while anything spawned
            # afterwards gets the new closure. That split-brain wedged hyprlock
            # on gti 2026-08-15 — the session had been up since 08-10 on
            # Hyprland 0.56.1, the 03:41 switch moved the system to 0.56.2, and
            # the next idle-lock launched a 0.56.2-era hyprlock against the
            # still-running 0.56.1 compositor. It never re-armed; seven
            # subsequent lock triggers were short-circuited by the
            # `pidof hyprlock ||` guard, and Hyprland's own recovery advice
            # (`hyprctl eval`) is unavailable on the .conf config format.
            # See docs/known-issues.md 2026-08-15.
            #
            # `boot` stages the generation as the next boot default and leaves
            # the running system untouched, so the closure only ever changes
            # across a reboot — where nothing has stale paths mapped.
            if /run/wrappers/bin/sudo /run/current-system/sw/bin/nixos-rebuild boot --flake "$CLAUDEOS_DIR#$HOST" 2>&1; then
              claudeos_notify \
                "Update Staged" "VM smoke test green — applied on next reboot."
              claudeos_lane_card auto-update "Flake updated & staged" "📦" normal \
                "$changelog"$'\n\n'"VM gate passed — staged on $HOST, active after next reboot."
            else
              claudeos_notify --urgency=critical \
                "Rebuild Failed" "VM gate was green but staging failed. Run 'rebuild' manually."
              claudeos_lane_card auto-update "Update built, staging failed" "📦" critical \
                "$changelog"$'\n\n'"VM gate was green but nixos-rebuild boot failed — run 'rebuild' manually."
              rm -f ./result ./result-vm
              exit 1
            fi
          else
            # KVM unavailable or vmTest disabled: build-only lane, never switch
            claudeos_notify \
              "Auto-Apply Skipped" "VM gate did not run (state: $vm_gate) — update built and pushed only. Apply with 'rebuild'."
          fi
        ''}
      else
        # Build failed — diagnose and revert. Opus: fires at most weekly and
        # only on failure, and post-update eval errors are exactly the gnarly
        # diagnosis work the stronger model is better at (cost doctrine: rare
        # high-stakes calls get opus).
        export CLAUDEOS_AGENT_ACTIVITY="diagnosing the failed build"
        diagnosis=$(claude_text opus "This NixOS build failed after flake update. Diagnose the issue briefly and suggest a fix. No markdown.

      $build_output")

        [[ -z "$diagnosis" ]] && diagnosis="Build failed after flake update. Run 'nix log' to see details."

        claudeos_notify --urgency=critical \
          "Update Build Failed" "$diagnosis"
        claudeos_lane_card auto-update "Update build failed" "📦" critical \
          "$diagnosis"$'\n\n'"flake.lock reverted."

        # Revert flake.lock
        git checkout flake.lock
        date -Iseconds > "$STATE_DIR/last-update-revert"
      fi

      rm -f ./result ./result-vm
    '';
  };
in
{
  options.claude-os.autoUpdate = {
    enable = lib.mkEnableOption "weekly automated NixOS flake updates with Claude review";

    autoApply = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to automatically run nixos-rebuild switch after a successful
        update build. Only happens when the VM smoke-test gate ran and was
        green; without usable KVM the run degrades to build-only (commit and
        push, no switch).
      '';
    };

    vmTest = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Gate updates on booting the freshly built generation in a throwaway
        QEMU VM (multi-user.target reached, no failed units, display manager active).
        Requires /dev/kvm; skipped gracefully when it is absent.
      '';
    };

    vmTestTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds the smoke-test VM gets to report a verdict before the run is declared red.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sat *-*-* 03:00:00";
      description = "Systemd calendar expression for when to run updates.";
    };
  };

  config = lib.mkIf cfg.enable {
    # autoApply needs root from a timer context. Scoped passwordless
    # nixos-rebuild for wheel — consistent with the decided security posture
    # (PHILOSOPHY.md: "Claude autonomy over hardening"); the gate in front of
    # it is the VM boot, not a password prompt.
    security.sudo-rs.extraRules = lib.mkIf cfg.autoApply [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Throwaway VM used by the smoke-test gate. Boots the next generation
    # headless before it may touch the real machine; strips hardware-specific
    # config that cannot exist inside QEMU. (sops secrets cannot decrypt in
    # the VM — the host SSH key never leaves the host — but sops-nix installs
    # secrets via an activation script here, which logs and continues, so it
    # cannot fail a unit and redden the gate.)
    virtualisation.vmVariant = lib.mkIf cfg.vmTest {
      virtualisation = {
        memorySize = 4096; # MiB
        cores = 2;
        graphics = false; # serial console only — the gate greps it; no GPU
        diskImage = null; # tmpfs root: nothing written, fully throwaway
      };

      # Hardware the VM does not have: disko's fileSystems point at real
      # partitions (the qemu-vm module supplies its own), snapper and scrub
      # need real btrfs, scx/thermald/fwupd need real hardware. throttled
      # (Intel CPU throttling fix, pulled in transitively by gti's
      # nixos-hardware dell-xps-13-9370 profile) reads real Intel MSRs and
      # crashes under QEMU — caught the auto-update VM gate red (throttled.service
      # in the failed-units list) on 2026-07-18.
      disko.enableConfig = lib.mkVMOverride false;
      services.snapper.configs = lib.mkVMOverride { };
      system.activationScripts.snapperSubvolumes.text = lib.mkVMOverride "";
      services.btrfs.autoScrub.enable = lib.mkVMOverride false;
      services.scx.enable = lib.mkVMOverride false;
      services.thermald.enable = lib.mkVMOverride false;
      services.fwupd.enable = lib.mkVMOverride false;
      services.throttled.enable = lib.mkVMOverride false;
      boot.plymouth.enable = lib.mkVMOverride false;

      systemd.services.claudeos-vm-smoke = {
        description = "ClaudeOS boot smoke test — report verdict on serial console, then power off";
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.systemd
          pkgs.coreutils
          pkgs.gawk
          pkgs.findutils
        ];
        # Type=exec, not oneshot: the boot transaction must be able to finish
        # while we wait on it, or `is-system-running --wait` deadlocks on our
        # own startup job.
        serviceConfig.Type = "exec";
        script = ''
          exec > /dev/console 2>&1
          # Wait for the startup transaction to settle ("running"/"degraded")
          status=$(systemctl is-system-running --wait || true)
          multiuser=$(systemctl is-active multi-user.target || true)
          # The login manager (greetd since the GNOME rip-out; GDM before)
          # runs as display-manager.service — never assert a literal
          # gdm/greetd unit name (that literal-unit assumption caused the
          # month-long silent-revert bug, PR #29).
          displaymgr=$(systemctl is-active display-manager.service || true)
          failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | xargs || true)
          if [ "$multiuser" = "active" ] && [ "$displaymgr" = "active" ] && [ -z "$failed" ]; then
            echo "CLAUDEOS-SMOKE-PASS status=$status"
          else
            echo "CLAUDEOS-SMOKE-FAIL status=$status multi-user=$multiuser display-manager=$displaymgr failed=''${failed:-none}"
            for u in $failed; do
              echo "--- journal: $u ---"
              journalctl -u "$u" -n 30 --no-pager || true
            done
          fi
          systemctl poweroff --no-wall
        '';
      };
    };

    systemd.user.services.claudeos-auto-update = {
      description = "ClaudeOS automated flake update with Claude review";
      # This unit's own script content (opus/sonnet swap, notify wording, …)
      # changes with the very generation switch it runs (autoApply branch,
      # sudo nixos-rebuild switch above). switch-to-configuration restarts
      # changed user units by default, which SIGTERMs this instance out from
      # under itself mid-switch — observed 2026-07-11 and 2026-07-26 as a
      # `code=killed, status=15/TERM` a few minutes into the switch. Disable
      # the self-restart; the next timer firing already picks up the new
      # script.
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString updateScript;
        TimeoutStartSec = "45min";
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
