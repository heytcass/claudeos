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
#
# 2026-11-01, second death (22:39): the sender audit came back empty, and
# hypridle never fired its 5-minute lock in the 25 minutes between the log's
# last line and the restart (it did so normally all evening). Idle events come
# from the compositor, so Hyprland was hung, not dead, long before it died —
# and a post-mortem cannot say where. Two more gaps:
#
#   3. Hang — a watchdog probes the live instance over its IPC socket. When it
#      stops answering, it snapshots every thread's backtrace (gdb) and kernel
#      wait point while the hang is still in progress. It runs as a system
#      service under the user with CAP_SYS_PTRACE only: yama ptrace_scope=1
#      forbids attaching to a non-descendant otherwise.
#   4. SIGTERM/SIGINT — also audited, since neither SIGKILL nor SIGHUP
#      explained the 22:39 exit.
#
# 2026-11-03, deaths at 07:25 and 08:46: same shape (log stops minutes early,
# no lock in the gap, no core, no audited sender), yet the watchdog never
# fired: hyprctl kept answering while the compositor had stopped. So:
#
#   5. Probe — also do a Wayland roundtrip on the instance's display socket,
#      which only the compositor's main loop can answer.
#   6. Lockout — the 07:25 death happened under hyprlock, and safe mode came
#      back on the crashed-lockscreen screen with no locker and no way in but
#      a reboot. Re-arm hyprlock in the successor (the relock that
#      misc.allow_session_lock_restore permits — see home/hyprland.nix).
{
  lib,
  pkgs,
  config,
  user,
  ...
}:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
  hmCfg = config.home-manager.users.${user};

  archiveScript = claudeLib.mkClaudeScript {
    name = "claudeos-hyprland-crash-archive";
    runtimeInputs = [ config.programs.hyprland.package ];
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

        # Give safe mode a working lock prompt. recoverycfg.lua leaves
        # allow_session_lock_restore off, so a session locked at the crash
        # shows a dead lockscreen; with it on, hyprlock takes the lock over.
        # If the session was not locked, this locks it, which a crash
        # restart should do anyway.
        export HYPRLAND_INSTANCE_SIGNATURE=$next
        hyprctl eval 'hl.config({ misc = { allow_session_lock_restore = true } })' || true
        hyprctl dispatch 'hl.dsp.exec_cmd("${lib.getExe hmCfg.programs.hyprlock.package}")' || true
        unset HYPRLAND_INSTANCE_SIGNATURE

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
          echo "hang captures: $(find "$STATE_DIR/hyprland-hangs" -maxdepth 1 -name "*-pid$pid" 2>/dev/null)"
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
            # Delivery can lag the crash by a whole safe-mode session, so say
            # when it happened. The archive is named for the restart time.
            base=''${dest##*/}
            when=$(date -d "''${base:0:10} ''${base:11:2}:''${base:13:2}" '+%a %b %-d, %H:%M' 2>/dev/null || echo "$base")
            claudeos_notify --urgency=critical "Hyprland crashed — $when" \
              "Restarted in safe mode. Evidence saved to $dest"
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

  hangWatchScript = claudeLib.mkClaudeScript {
    name = "claudeos-hyprland-hang-watch";
    runtimeInputs = [
      pkgs.gdb
      # hyprctl must speak the running compositor's IPC.
      config.programs.hyprland.package
      pkgs.wayland-utils
    ];
    text = ''
      hypr_dir="/run/user/$(id -u)/hypr"
      hang_root="$STATE_DIR/hyprland-hangs"
      # 5 s cost ~1.2% CPU in process spawns; a hang is minutes long anyway.
      interval=10
      # Consecutive failed probes before a hang is declared (~30-40 s).
      threshold=3
      keep=10

      snapshot() { # <pid> <file>
        local pid=$1 out=$2 t
        {
          echo "### $(date -Is) pid $pid"
          echo "### /proc/$pid/status"
          cat "/proc/$pid/status"
          echo "### per-thread state / wchan / syscall"
          for t in /proc/"$pid"/task/*; do
            printf '%s %-16s state=%s wchan=%s syscall=%s\n' "''${t##*/}" \
              "$(cat "$t/comm")" "$(awk '{print $3}' "$t/stat")" \
              "$(cat "$t/wchan" 2>/dev/null)" "$(cat "$t/syscall" 2>/dev/null)"
          done
          echo "### open fds"
          find "/proc/$pid/fd" -mindepth 1 -printf '%l\n' | sed 's/:\[[0-9]*\]$//' \
            | sort | uniq -c | sort -rn | head -40
          echo "### gdb: all threads"
          timeout 90 gdb -p "$pid" -batch -nx \
            -ex 'set pagination off' -ex 'thread apply all bt 40' 2>&1
        } >"$out" 2>&1
      }

      failures=0
      captured="" # instance already snapshotted during the current hang
      while sleep "$interval"; do
        # Newest instance whose lock names a live process.
        sig="" pid=""
        while read -r name; do
          p=$(head -n1 "$hypr_dir/$name/hyprland.lock" 2>/dev/null || true)
          if [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; then
            sig=$name pid=$p
            break
          fi
        done < <(find "$hypr_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
          | sort -t_ -k2,2nr -k3,3nr)
        if [[ -z "$pid" ]]; then
          failures=0
          continue
        fi

        # hyprctl alone kept answering through both 2026-11-03 stalls; the
        # Wayland roundtrip needs the main loop. Line 2 of the lock is the
        # instance's display socket.
        wl=$(sed -n 2p "$hypr_dir/$sig/hyprland.lock" 2>/dev/null || true)
        failed=""
        HYPRLAND_INSTANCE_SIGNATURE=$sig timeout 3 hyprctl -j version >/dev/null 2>&1 \
          || failed+=" hyprctl"
        if [[ -n "$wl" ]]; then
          XDG_RUNTIME_DIR="/run/user/$(id -u)" WAYLAND_DISPLAY=$wl timeout 3 wayland-info >/dev/null 2>&1 \
            || failed+=" wayland"
        fi
        if [[ -z "$failed" ]]; then
          if [[ "$captured" == "$sig" ]]; then
            echo "instance $sig responsive again after a captured hang"
            echo "recovered $(date -Is)" >>"$dest/summary.txt"
          fi
          failures=0 captured=""
          continue
        fi
        failures=$((failures + 1))
        ((failures >= threshold)) || continue
        [[ "$captured" == "$sig" ]] && continue

        captured=$sig
        dest="$hang_root/$(date +%Y-%m-%dT%H%M%S)-pid$pid"
        mkdir -p "$dest"
        echo "Hyprland $pid unresponsive for $failures probes; capturing to $dest"
        {
          echo "instance:     $sig"
          echo "pid:          $pid"
          echo "detected:     $(date -Is) after $failures failed probes ''${interval}s apart"
          echo "failing:     $failed"
        } >"$dest/summary.txt"
        snapshot "$pid" "$dest/stack-1.txt"
        # A second look separates a deadlock (same stacks) from a livelock.
        sleep 30
        if kill -0 "$pid" 2>/dev/null; then
          snapshot "$pid" "$dest/stack-2.txt"
        fi
        cp -a "$hypr_dir/$sig/hyprland.log" "$dest/" 2>/dev/null || true
        journalctl --since "-5min" -o short-precise --no-pager \
          >"$dest/journal.txt" 2>&1 || true

        find "$hang_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r \
          | tail -n +$((keep + 1)) | while read -r old; do rm -rf "''${hang_root:?}/$old"; done
      done
    '';
  };
in
{
  config = lib.mkIf config.claude-os.hyprland.enable {
    # Who sent the signal. kill/tkill/pidfd_send_signal carry the signal in a1,
    # tgkill in a2. 9 = SIGKILL, 1 = SIGHUP, 15 = SIGTERM, 2 = SIGINT.
    security.audit.rules =
      lib.concatMap
        (sig: [
          "-a always,exit -F arch=b64 -S kill -S tkill -S pidfd_send_signal -F a1=${sig} -k kill-signal"
          "-a always,exit -F arch=b64 -S tgkill -F a2=${sig} -k kill-signal"
        ])
        [
          "9"
          "1"
          "15"
          "2"
        ];

    # A system unit (not a user one) so it can hold CAP_SYS_PTRACE; it runs as
    # the user so the IPC socket and state dir are its own.
    systemd.services.claudeos-hyprland-hang-watch = {
      description = "Snapshot Hyprland's stacks when it stops answering IPC";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = hangWatchScript;
        User = user;
        AmbientCapabilities = [ "CAP_SYS_PTRACE" ];
        CapabilityBoundingSet = [ "CAP_SYS_PTRACE" ];
        Restart = "always";
        RestartSec = 10;
        Nice = 10;
        SyslogIdentifier = "hyprland-hang-watch";
      };
    };

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
    #
    # Not debug.enable_stdout_logs: tried 2026-11-03, and on 0.57 it is inert —
    # the option reads true but nothing past init reaches stdout. The archive
    # above is the log's only way off tmpfs.
    home-manager.users.${user}.wayland.windowManager.hyprland.settings.config.debug.disable_time =
      false;
  };
}
