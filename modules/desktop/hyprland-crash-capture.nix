# modules/desktop/hyprland-crash-capture.nix — leave evidence the next time
# Hyprland dies without a crash report.
#
# 2026-11-01: Hyprland died at 18:35 while the user was away, and start-hyprland
# relaunched it in --safe-mode. There was no crash report, coredump or OOM
# entry, and the log's last ~10 minutes were still in the logger's buffer.
# Hyprland's own handler covers SIGSEGV/SIGABRT (report plus abort/coredump),
# so silence points to an uncatchable signal (SIGKILL) or a SIGHUP, and nothing
# recorded who sent it. Two gaps to close:
#
#   1. Sender — audit every SIGKILL/SIGHUP sent by syscall. Kernel-originated
#      kills (OOM, PDEATHSIG) don't go through a syscall; those already leave
#      their own journal lines.
#   2. Log — every instance's dir under $XDG_RUNTIME_DIR/hypr survives the
#      death (with linger the runtime dir is never wiped), but nothing kept it
#      past the next reboot. A path unit fires when a new instance dir appears.
#      If the successor booted in safe mode, it archives the dead predecessor's
#      log with the journal/audit/coredump window around the death, then
#      notifies.
{
  lib,
  pkgs,
  config,
  user,
  ...
}:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };

  archiveScript = claudeLib.mkClaudeScript {
    name = "claudeos-hyprland-crash-archive";
    text = ''
      hypr_dir="''${XDG_RUNTIME_DIR:?}/hypr"
      archive_root="$STATE_DIR/hyprland-crashes"
      seen="$archive_root/.seen"
      pending="$archive_root/.pending"
      keep=10
      mkdir -p "$archive_root"
      touch "$seen"

      # Fired by the new instance's dir appearing; recoverycfg.lua lands a
      # moment later.
      sleep 5

      # Instance dirs are <commit>_<epoch>_<nanos>; sort by start time.
      mapfile -t dirs < <(find "$hypr_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
        | sort -t_ -k2,2n -k3,3n)

      for i in "''${!dirs[@]}"; do
        name=''${dirs[$i]}
        d="$hypr_dir/$name"
        grep -qxF "$name" "$seen" && continue
        pid=$(head -n1 "$d/hyprland.lock" 2>/dev/null || true)
        [[ -n "$pid" ]] || continue
        kill -0 "$pid" 2>/dev/null && continue # still running

        # Need a successor to judge clean exit vs crash; retry next trigger.
        next=''${dirs[$((i + 1))]:-}
        [[ -n "$next" ]] || continue
        echo "$name" >>"$seen"
        [[ -f "$hypr_dir/$next/recoverycfg.lua" ]] || continue # clean exit

        start=$(cut -d_ -f2 <<<"$name")
        restart=$(cut -d_ -f2 <<<"$next")
        last_log=$(stat -c %Y "$d/hyprland.log" 2>/dev/null || echo "$start")
        since="@$((last_log - 120))"
        until="@$((restart + 30))"
        dest="$archive_root/$(date -d "@$restart" +%Y-%m-%dT%H%M%S)"
        mkdir -p "$dest"

        cp -a "$d/hyprland.log" "$dest/" 2>/dev/null || true
        {
          echo "instance:      $name"
          echo "pid:           $pid"
          echo "started:       $(date -d "@$start")"
          echo "log last write $(date -d "@$last_log")"
          echo "safe restart:  $(date -d "@$restart")"
          echo "crash reports: $(find "''${XDG_CACHE_HOME:-$HOME/.cache}/hyprland" -name "hyprlandCrashReport$pid*" 2>/dev/null)"
        } >"$dest/summary.txt"
        cp -a "''${XDG_CACHE_HOME:-$HOME/.cache}"/hyprland/hyprlandCrashReport"$pid"* "$dest/" 2>/dev/null || true
        journalctl --user --since "$since" --until "$until" -o short-precise --no-pager \
          >"$dest/user-journal.txt" 2>&1 || true
        journalctl --since "$since" --until "$until" -o short-precise --no-pager \
          >"$dest/system-journal.txt" 2>&1 || true
        # The audit rules below tag kill syscalls with this key; the OBJ_PID
        # record next to each SYSCALL names the target (ocomm=).
        journalctl _TRANSPORT=audit --since "$since" --until "$until" -o short-precise --no-pager \
          | grep -A3 'key="kill-signal"' >"$dest/kill-audit.txt" 2>&1 || true
        coredumpctl list --since "$since" --until "$until" --no-pager \
          >"$dest/coredumps.txt" 2>&1 || true

        echo "$dest" >>"$pending"
      done

      # Safe mode runs no bar, so nothing serves notifications. Queue them and
      # deliver once a server is up — in practice the next normal login, whose
      # new instance dir fires this unit again.
      if [[ -s "$pending" ]]; then
        for _ in $(seq 45); do
          busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 && break
          sleep 2
        done
        if busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; then
          while read -r dest; do
            claudeos_notify --urgency=critical "Hyprland crashed and restarted in safe mode" \
              "Evidence saved to $dest"
          done <"$pending"
          : >"$pending"
        fi
      fi

      # Keep the newest $keep archives.
      find "$archive_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r \
        | tail -n +$((keep + 1)) | while read -r old; do rm -rf "''${archive_root:?}/$old"; done
      # Forget instance dirs that no longer exist.
      grep -xFf <(find "$hypr_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n') "$seen" \
        >"$seen.tmp" || true
      mv "$seen.tmp" "$seen"
    '';
  };
in
{
  config = lib.mkIf config.claude-os.hyprland.enable {
    # Who sent the signal. kill/tkill/pidfd_send_signal carry the signal in a1,
    # tgkill in a2. 9 = SIGKILL, 1 = SIGHUP.
    security.audit.rules =
      lib.concatMap
        (sig: [
          "-a always,exit -F arch=b64 -S kill -S tkill -S pidfd_send_signal -F a1=${sig} -k kill-signal"
          "-a always,exit -F arch=b64 -S tgkill -F a2=${sig} -k kill-signal"
        ])
        [
          "9"
          "1"
        ];

    systemd.user.paths.claudeos-hyprland-crash-archive = {
      description = "Watch for new Hyprland instances (crash evidence)";
      wantedBy = [ "default.target" ];
      pathConfig.PathChanged = "%t/hypr";
    };

    systemd.user.services.claudeos-hyprland-crash-archive = {
      description = "Archive a dead Hyprland instance's log after a safe-mode restart";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = archiveScript;
        SyslogIdentifier = "hyprland-crash-archive";
      };
    };

    # Timestamps in hyprland.log so it lines up with the journal.
    home-manager.users.${user}.wayland.windowManager.hyprland.settings.config.debug.disable_time =
      false;
  };
}
