# modules/common/auto-update.nix — Weekly unattended NixOS flake updates with Claude review.
#
# Flow: nix flake update → build test → VM smoke-test gate → Claude-reviewed
# changelog → commit & push → nixos-rebuild switch (autoApply) → notify
#
# The VM gate is what makes autoApply safe: the freshly built generation is
# booted headless in a throwaway QEMU VM (config.system.build.vm with a
# vmVariant that strips hardware-specific config) and must reach
# multi-user.target with zero failed units and gdm.service active before the
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
            notify-send --app-name=ClaudeOS --urgency=critical \
              "Update Blocked: VM Smoke Test" "$fail_line"
            git checkout flake.lock
            cleanup
            rm -f ./result ./result-vm "$vm_log"
            exit 1
          fi
          [[ -n "$vm_log" ]] && rm -f "$vm_log"
          # ------------------------------------------------------------------

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
            if [[ "$vm_gate" == "passed" ]]; then
              if sudo /run/current-system/sw/bin/nixos-rebuild switch --flake "$CLAUDEOS_DIR#$HOST" 2>&1; then
                notify-send --app-name=ClaudeOS \
                  "System Rebuilt" "VM smoke test green — auto-update applied."
              else
                notify-send --app-name=ClaudeOS --urgency=critical \
                  "Rebuild Failed" "VM gate was green but the switch failed. Run 'rebuild' manually."
                cleanup
                rm -f ./result ./result-vm
                exit 1
              fi
            else
              # KVM unavailable or vmTest disabled: build-only lane, never switch
              notify-send --app-name=ClaudeOS \
                "Auto-Apply Skipped" "VM gate did not run (state: $vm_gate) — update built and pushed only. Apply with 'rebuild'."
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
        rm -f ./result ./result-vm
  '';
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
        QEMU VM (multi-user.target reached, no failed units, gdm active).
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
      # need real btrfs, scx/thermald/fwupd need real hardware.
      disko.enableConfig = lib.mkVMOverride false;
      services.snapper.configs = lib.mkVMOverride { };
      system.activationScripts.snapperSubvolumes.text = lib.mkVMOverride "";
      services.btrfs.autoScrub.enable = lib.mkVMOverride false;
      services.scx.enable = lib.mkVMOverride false;
      services.thermald.enable = lib.mkVMOverride false;
      services.fwupd.enable = lib.mkVMOverride false;
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
          gdm=$(systemctl is-active gdm.service || true)
          failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | xargs || true)
          if [ "$multiuser" = "active" ] && [ "$gdm" = "active" ] && [ -z "$failed" ]; then
            echo "CLAUDEOS-SMOKE-PASS status=$status"
          else
            echo "CLAUDEOS-SMOKE-FAIL status=$status multi-user=$multiuser gdm=$gdm failed=''${failed:-none}"
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
