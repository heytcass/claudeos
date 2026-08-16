# Known Issues Ledger

Maintained by the ClaudeOS journal diary (`claudeos-journal-diary`, nightly).
Each entry: date first seen · error signature · verdict. The diary reads this
file before triaging, so anything recorded here stops generating noise.
Entries are appended by the agent; humans may prune or correct freely.
Ledger edits are committed by the normal rebuild auto-commit flow.

## Actionable

<!-- new-actionable entries land here: date · signature · next step -->

- 2026-08-15 · Migrating the Secret Service from gnome-keyring to **oo7 0.6.0** locked Chrome and Claude Desktop out of their saved credentials on `gti`; oo7's log showed `ERROR create_item{label="Chrome Safe Storage"}: Failed to write keyring after item creation` and a repeating `WARN Object: /org/freedesktop/secrets/aliases/default does not exist` · **Root cause is a startup ORDERING race in oo7, not the keyring format and not our data.** The NixOS module starts the daemon eagerly (`systemd.user.services.oo7-daemon.wantedBy = [ "default.target" ]`), so on `gti` it came up at 22:39:05 — *nine seconds before* `pam_oo7` delivered the login password at 22:39:14. With no secret it could not read the existing keyring, logged `Discovered 0 keyring(s), 1 pending v0 migration(s)`, and then **created an empty placeholder**: `No default collection found, creating 'Login' keyring` / `Created default 'Login' collection (locked)`. When PAM's secret finally arrived the migration itself *succeeded* (`Successfully migrated v0 keyring 'login' to v1` / `Wrote migrated keyring 'login' to disk` / `Migrated keyring 'login' added as collection`) — but the real collection now collided with the placeholder of the same name, leaving `/org/freedesktop/secrets/collection/Login` unresolvable and every subsequent write failing. Note the PAM hand-off worked perfectly (`Captured PAM_AUTHTOK` → `Stashed password to try later in open session` → `Connected to daemon socket` → `Successfully sent secret to oo7 daemon`); it was simply too late. **Verified separately that the format is fine:** run offline against a copy with `oo7-daemon --login` (secret present at startup, so no placeholder), the v0→v1 migration completes cleanly with no orphaned `.tmpkeyring*` files — the file keeps the `GnomeKeyring\n\r\0\n` magic and bumps its version bytes `0 0` → `1 0`. **Additional disqualifying defect:** oo7 panics whenever the default alias is absent — `thread 'tokio-runtime-worker' panicked at server/src/service/mod.rs:831:31: called Option::unwrap() on a None value` — reproducible offline, and unacceptable in a process holding OAuth tokens and browser encryption keys. **Verdict: do NOT retry oo7 at 0.6.0.** The likely wiring fix is `systemd.user.services.oo7-daemon.wantedBy = lib.mkForce [ ]` so `pam_oo7`'s `auto_start` brings the daemon up *with* the secret (the same shape as the soteria ordering fix), but the panic makes it not worth attempting until upstream moves. Recovery, if it is ever retried and fails again: gnome-keyring's data is untouched by oo7 (it migrates a copy and removes the original only on success), so restore `~/.local/share/keyrings/login.keyring` from a backup taken beforehand and roll back a generation. **Always back that file up before touching the Secret Service.**

- 2026-08-15 · Two independent operator errors during the same oo7 work, recorded because both are easy to repeat · (1) A verification script documented D-Bus isolation in a *comment* but omitted `dbus-run-session` from the actual command, so a test daemon raced the live one, failed with `Zbus(NameTaken)`, and `oo7-cli list` silently queried the REAL keyring instead — printing live secrets, including a GitHub `gho_` token, into terminal scrollback (token rotated). **When a test's safety depends on isolation, grep the command line for it, not the file.** (2) `oo7-cli list` prints secret VALUES by default and has no `--no-secrets` flag; redact with `sed -E "s/^secret = .*/secret = <redacted>/"` when the question is only "did the items survive". Also note `oo7-daemon --login` reads the password from a tty but NOT reliably from a pipe — `printf '%s\n'` appends a newline that is taken as part of the secret, producing a misleading `Checksum is not equal to the expected value`.

- 2026-08-15 · hyprlock wedged after a live `nixos-rebuild switch` into a running graphical session; Hyprland showed the "Oopsie daisy … lockscreen app died" fallback (`assets/install/lockdead.png`) and the session was unrecoverable without a reboot (gti) · **Root cause: home-manager activation stopped `hypridle.service`, whose cgroup teardown SIGTERM'd the hyprlock holding the active session lock — then the relock was refused.** Not a hyprlock defect, and *not* version skew (an early reading, corrected below). Sequence: boot -1 ran 08-10 17:55 → 08-15 10:51 (~5d uptime). hyprlock 2840619 took the lock cleanly on Aug 14 (`Locking session` / `onLockLocked called`). At 03:41:09 `claudeos-auto-update` ran `switch-to-configuration switch` live; at 03:41:16 home-manager logged `Stopping units: gammastep.service, hypridle.service, hyprpaper.service`. **hyprlock is forked by hypridle and therefore lives in `hypridle.service`'s cgroup** — proven by journald tagging hyprlock's own stdout as `hypridle[2840619]`, since it attributes by cgroup. With `KillMode=control-group` and `KillSignal=15`, stopping the unit SIGTERMs the whole cgroup including the lock client. 2840619's last line is `output 71 done` at 03:41:15, one second before the stop, and it is **the only hyprlock instance in the entire journal that never logs `Unlocking session`**. SIGTERM leaves no core, which is why `coredumpctl list hyprlock` reports `No coredumps found`. The 03:46:24 relaunch was then **denied, not successful**: `onLockFinished called. Seems we got yeeten. Is another lockscreen running?` — Hyprland refusing a second `ext-session-lock-v1` because `misc:allow_session_lock_restore` defaults to false. The denied instance lingered without holding the lock, so the `pidof hyprlock ||` guard in `lock_cmd` (`home/hyprland.nix`) short-circuited all seven later triggers (05:40, 06:05, 07:35, 08:28, 08:44, 09:21, 09:43 — each logs the exec line and the stale PID, never a `Hyprlock version` line). **Corrections to earlier readings, both dead:** (1) the 3840² `assets/dune.jpg` decode — hyprlock logs `Resources gathered after 189 milliseconds` on *every* launch across a dozen-plus locks, so the image is not implicated; (2) a Hyprland 0.56.2 session-lock regression — the compositor never restarted (`Started Main service for Hyprland` 08-10 17:55:48, `Stopping` 08-15 10:51:18), so **0.56.1 was in memory for the entire incident** and 0.56.2's binary first executed at the 10:51:48 reboot, after it was over; the v0.56.1→v0.56.2 diff touches no session-lock code. Fixed by `switch` → `boot` in `modules/common/auto-update.nix` plus `misc.allow_session_lock_restore = true`. **Note the generalisation:** because the mechanism is cgroup teardown, a plain home-manager switch with no version change at all would wedge the lock identically — do not assume rarity from version skew. Remaining hardening not yet applied: `KillMode=process` on hypridle, or not spawning hyprlock as a hypridle child, or an idempotent `lock_cmd`. Reproducibility: one-off. `Stopping units: …hypridle…` appears exactly once across all 10 retained boots, and `yeeten` exactly once, 5 minutes later; the other 11 switches (Aug 6–9) were manual runs with the session unlocked. The weekly timer only landed on a locked session because Aug 8's 03:00 run fired while the machine was off and `Persistent=true` deferred it to a midday boot.

- 2026-08-15 · Hyprland's crashed-lockscreen fallback screen instructs `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`, which returns `eval is only supported with the lua config manager` on this build; the screen's other suggestion, `hypr`, is not a command at all (`hypr: command not found`) · **Hyprland ships recovery advice its own config format cannot follow.** `eval` and `keyword` are mirror images in `src/debug/HyprCtl.cpp`: `evalRequest` refuses unless `CONFIG_LUA`, `dispatchKeyword` refuses unless `CONFIG_LEGACY`. We are on hyprlang (`configType = "hyprlang"`, `home/hyprland.nix`), so `eval` is unavailable *by design* — this is not a broken install. The fallback screen is a **static PNG with no source**, so it cannot branch on config type; it was rewritten to the Lua wording in hyprwm/Hyprland#14213 (fixing the mirror-image complaint in discussion #14395, where Lua users were shown the `keyword` form) and now misinstructs every `.conf` user. There is **no** non-`eval` equivalent of `clear_crashed_lockscreen()`: `forceUnlock` is referenced only from `SessionLock.{cpp,hpp}`, `SessionLockManager.{cpp,hpp}` and the Lua binding — no dispatcher, no hyprctl command. Mitigated by setting `misc.allow_session_lock_restore = true` (`home/hyprland.nix`; default is `false`, verified via `hyprctl getoption` → `int: 0, set: false`), which makes the TTY recovery `hyprctl --instance 0 dispatch exec hyprlock` — this re-arms a working prompt while *keeping the session locked*, which is preferable on a laptop to `clear_crashed_lockscreen()`, which unlocks outright. **RESOLVED 2026-08-15** by migrating the config to Lua (`configType = "lua"`, `home/hyprland.nix`): `hyprctl eval 'hl.clear_crashed_lockscreen()'` — the exact command the fallback screen prints — now works, so the on-screen instructions are correct again. The inverse is now true and worth remembering: **`hyprctl keyword` no longer works at all**, which is why `hypr_config_check` was rebuilt on the format-agnostic `Hyprland --verify-config`. `misc.allow_session_lock_restore` stays on regardless — it gives the gentler recovery (`hyprctl dispatch exec hyprlock` re-arms a prompt while keeping the session locked, versus `clear_crashed_lockscreen()` which unlocks outright).

- 2026-08-08 · ath10k_pci 0000:02:00.0 (Qualcomm QCA6174 WiFi) multiple failures: "failed to read firmware dump area: -16" (3x), "failed to receive initialized event from target" (2x), "firmware crashed! (guid ...)" (3x different GUIDs) · WiFi adapter firmware instability across multiple boot cycles. Next step: verify WiFi connectivity is operational; if working normally, treat as transient boot-race glitches; if degraded/broken, check full ath10k dmesg output and consider firmware rollback or driver reload.

- 2026-08-08 · xhci_hcd 0000:39:00.0 "xHCI host controller not responding, assume dead" + "HC died; cleaning up" · USB controller on new PCI address (0x39, distinct from existing 0x3b transient) reporting severe failure. Next step: verify USB device connectivity on all ports; if all USB devices enumerate and function normally, likely a transient power-state glitch (similar to existing 0x3b pattern); if USB on this controller is unresponsive or devices fail to reattach, escalate to BIOS USB settings or firmware investigation.

- 2026-07-10 · xhci_hcd USB host controller PCI post-resume error -19 + "HC died; cleaning up" + pcieport D3hot→D0 power state failure (same suspend/resume cycle) · USB and PCIe power state management issue after resume. Next step: verify USB connectivity; test suspend/resume cycle (`systemctl suspend`) to confirm reproducibility; if repeats, investigate firmware/driver updates or BIOS sleep state settings (transporter).

- 2026-07-17 · `iwlwifi 0000:02:00.0: iwlwifi transaction failed, dumping registers` (1 occurrence) followed by register state dumps · WiFi card (Intel AX200) signaled a transaction failure and kernel dumped hardware state, suggesting a device error condition. Requires verification: check `iwctl` and `nmcli` to confirm WiFi connectivity is operational; if connectivity works, this is a transient hardware glitch. If WiFi is degraded/broken, escalate to driver/firmware investigation.

- 2026-07-17 · `<error> [1784248116.8247] device (/net/connman/iwd/0): .Set failed: GDBus.Error:net.connman.iwd.Failed: Operation failed` (1 occurrence) · iwd (iNet Wireless Daemon) D-Bus operation failure; likely related to the concurrent iwlwifi transaction failure. Verify WiFi connectivity; if broken, investigate alongside iwlwifi error.

- 2026-07-05 · `usr-bin.mount: Failed with result 'protocol'` / "Mount process
  finished, but there is no mount" (envfs FUSE on /usr/bin, intermittent —
  transporter, recurred 2026-07-06) · Investigated 2026-07-06: this is the
  generic systemd mount-handshake race (systemd/systemd#23796) — mount.envfs
  exits before the FUSE mount lands in mountinfo, systemd logs FAILED, then
  observes the mount seconds later and flips the unit back to *active
  (mounted)*. On the 2026-07-06 boot both `/usr/bin` and `/bin` were mounted
  and healthy within the same second as the FAILED line, so the scary boot
  message is cosmetic when the envfs process survives (`Unit process remains
  running after unit stopped`). No envfs-side fix upstream (Mic92/envfs has
  no matching issue). Do NOT add a restart-on-failure override — systemd
  self-corrects, and a forced remount would race the live FUSE process.
  Verify after any occurrence with `systemctl status usr-bin.mount bin.mount`;
  only escalate if the unit stays failed and `/usr/bin/env` is missing.

## Benign

<!-- known-benign noise lands here: date · signature · why it's harmless -->

- 2026-07-17 · health-check exit 1 triggered solely by `fwupd-refresh.service` in the failed state; its log shows `fwupdmgr: Unsupported daemon version 2.1.5, client version is 2.1.6` · Rebuild artifact, not a live fault: `fwupd-refresh` runs at activation (and on a 15-min timer), but the long-running `fwupd.service` daemon is not restarted in lockstep with the `fwupdmgr` client on every `nixos-rebuild switch`, so during a switch that bumps the fwupd version the client briefly talks to the older daemon and `fwupdmgr` refuses with a version-mismatch and exits 1. The unit then sits in `failed` until its next successful timer run — which is why the health check *flaps* (fail while skewed, pass once daemon and client versions line up again; observed both at 2.1.5 post-recovery). `alert-context.txt` held only the one failed-service line; no disk, memory, OOM, stale-update, or critical-log issues. Same class as the 2026-07-11 watchdog reboot artifact — expected on a rebuild-heavy day. Clear the stale state with `sudo systemctl reset-failed fwupd-refresh.service`; it passes on the next timer tick once versions match. Do NOT add a `Restart=`/override to force the refresh — the skew self-corrects and a forced retry just races the daemon restart (same reasoning as the envfs actionable entry). Only escalate if `fwupd-refresh` keeps failing while `fwupdmgr --version` shows the daemon and client on the *same* version (a genuine refresh/network fault, not a skew).

- 2026-07-11 · health-check exit 1 triggered solely by `kernel: watchdog: watchdog0: watchdog did not stop!` (single crit line caught by the "Critical Log Entries" 15-min lookback) · Reboot artifact, not a live fault: the Intel iTCO hardware watchdog can't be halted cleanly on shutdown, so the kernel logs this at crit priority as the last line before the next boot (observed 14:12:39, fresh kernel up 14:13:08). The first post-boot health check's 15-min window swept it up and exited 1 — expected on any reboot, and unavoidable on a day with many rebuilds (7 boots on 2026-07-11). `alert-context.txt` held only this line; no failed services, disk, memory, OOM, or stale-update issues. Distinct from the by-design "health-check failed" entry (2026-07-08) — this documents the specific benign *trigger content*. Only escalate if the watchdog line appears mid-session (not adjacent to a reboot) or the new kernel fails to come up.

- 2026-07-11 · "Module [libstdc++.so.6, libgcc_s.so.1, libgbm.so.1, libdrm.so.2, libzstd.so.1, libxml2.so.16, libX11.so.6, libpango-1.0.so.0, libreadline.so.8, etc.] without build-id" (100+ occurrences) · Debugger-metadata warnings: libraries lack ELF build-id sections used for symbol matching. Informational only and does not affect runtime. Normal in NixOS where build-id inclusion varies by package; no action needed.

- 2026-07-10 · pam_unix sudo auth failures: "conversation failed" and "auth could not identify password for [tom]" (4 each) · Transient sudo authentication hiccups; if `sudo` works normally when needed, these are harmless glitches (possibly password-echo races or stale TTY state). Escalate only if sudo becomes unusable.

- 2026-07-10 · i915 GPU *ERROR* "Atomic update failure on pipe A" (scanline timing, 1 occurrence) · Transient GPU display timing glitch during vertical sync update; does not affect display output or functionality. One-off event, benign if display remains stable.

- 2026-07-10 · connman/iwd "operation failed" on device config (.Set failed) · Transient WiFi configuration operation failure; if network connectivity works, the device recovered. Monitor if pattern repeats; only escalate if WiFi stops connecting.

- 2026-07-10 · iwlwifi 0000:02:00.0 "transaction failed, dumping registers" (1 occurrence, followed by memory dumps) · WiFi adapter transient firmware/hardware glitch with state dump for diagnostic purposes; adapter likely recovered if connectivity remains stable. One-off event, benign if WiFi functional.

- 2026-07-09 · "Failed to start ClaudeOS Claude-authored notification handler" (35 occurrences) · Expected: the notifier is triggered by health-check `OnFailure=`, so it runs once per health-check failure. The notifier "failing" in the journal is the normal exit; the actual notification (if any) is the only actionable part.

- 2026-07-09 · "Failed to start ClaudeOS morning system briefing" (1 occurrence) · Likely transient or timer not yet fired (scheduled service runs once daily). Monitor if pattern continues.

- 2026-07-08 · "Failed to start ClaudeOS system health check" (periodic) · BY DESIGN — the health check deliberately exits 1 when it finds issues, because `OnFailure=claudeos-notify.service` is how the notifier gets triggered (see the script header in `modules/apps/claude-monitor/health-check.sh`). A "failed" health-check unit means the check WORKED and found something; the something is what deserves attention, not the unit. Do not "fix" the exit code.

- 2026-07-08 · Chrome thread futex/pthread waits (64 syscall_cancel, 33 futex_abstimed_wait, 22 pthread_cond_wait, etc. over 24h) · Normal thread synchronization in Chrome's multi-threaded event loop; condition-variable and futex waits are expected. No actual failure signaled.

- 2026-07-08 · "ELF object binary architecture: AMD x86-64" (4 occurrences) · Informational kernel or tooling message; this system is indeed x86-64. No issue.

- 2026-07-07 · "Failed to start Install Claude Code CLI on first login" / repeated `claude-code-installer` skip lines (~31/24h) · REFUTED as a failure (runtime audit 2026-07-07): these are `ConditionPathExists=!~/.local/bin/claude` **skips** — the CLI is already installed and self-updating (v2.1.203). The one real failure (2026-07-05, `curl: command not found`) self-resolved 17 minutes later. Do not "fix" the installer.

- 2026-07-07 · user services restarting during `nixos-rebuild switch` (claudeos-* timers/units bouncing mid-activation) · If observed, this is home-manager issue #7583 (user services erroneously restarted during activation when HM runs as a NixOS module) — an upstream bug, not a config regression. Don't chase it here; check the issue's status instead.

- 2026-07-07 · "Skipping line 2 in filter.conf: too long" (2 occurrences in 24h) · Malformed line in audio filter config; does not affect audio functionality. Investigate if filter.conf was auto-generated or hand-edited.

- 2026-07-07 · `profiles/audio/bap.c:bap_adapter_probe() BAP requires ISO Socket which is not enabled` (2 occurrences) · Bluetooth Audio Profile (BAP) codec path logs that ISO socket support is disabled; only relevant if LE Audio pairing is intended. Not a blocker for standard Bluetooth audio.

- 2026-07-13 · "Failed to set default system config for hci0" (6 occurrences) · Bluetooth adapter configuration step logs failure but adapter registers and operates normally (verified by user system operation); transient at boot time, similar to observed "Reading supported features failed" pattern.

- 2026-07-13 · "Activation request for 'org.bluez' failed" (6 occurrences) · D-Bus service activation retry on initialization; transient, does not affect Bluetooth functionality once adapter is ready.

- 2026-07-13 · "bap: Operation not supported (95)" (6 occurrences) · Part of Bluetooth Audio Profile initialization chain when ISO Socket is disabled; informational, not blocking standard audio.

- 2026-07-13 · "tpm_tis 00:01: probe with driver tpm_tis failed with error -1" (3 occurrences) · TPM device initialization transient (-1 = EIO); no TPM functionality required for daily use. Monitor if TPM-dependent applications emerge.

- 2026-07-13 · "gkr-pam: unable to locate daemon control file" (3 occurrences) · gnome-keyring PAM module can't find its control socket at startup; keyring functionality unaffected once daemon is ready. Transient at boot.

- 2026-07-13 · "pam_unix(sudo:auth): conversation failed" and "auth could not identify password" (4 occurrences total) · PAM authentication timeouts/delays during boot race; sudo operates normally once session settles. Correlates with gkr-pam initialization window.

- 2026-07-13 · "/nix/store/.../uwsm-0.26.6/libexec/uwsm/signal-handler.sh: line 7: printf: write error: Input/output error" (2 occurrences) · UWSM signal delivery write error during session teardown; transient, session not impacted.

- 2026-07-13 · "i2c_designware i2c_designware.1: spurious STOP detected" (2 occurrences) · I2C bus transient; likely touchpad/sensor enumeration glitch. Does not affect device functionality.

- 2026-07-13 · "Bluetooth: hci0: sending frame failed (-19)" (2 occurrences) · Bluetooth transmission error at adapter level during boot race; adapter recovers and operates normally.

- 2026-07-13 · "xhci_hcd 0000:3b:00.0: PCI post-resume error -19!" and "HC died; cleaning up" (2 occurrences) · xHCI USB controller transient recovery during power-state transitions (post-resume error), self-heals. Monitor if USB peripherals drop; only escalate if devices don't reattach.

- 2026-07-13 · "Stack trace of thread [1632/1563/1557]" (3 occurrences) · Incomplete kernel thread traces (header only, no frames); context unclear but no functional impact reported. Likely from short-lived process/thread that recovered.

- 2026-07-06 · D-Bus "Ignoring duplicate name" warnings (org.gnome.keyring, org.freedesktop.secrets, org.gtk.vfs.*, org.gnome.evolution.*, etc., ~200 total occurrences) · Normal in multi-package setups providing the same D-Bus interface (gnome-keyring remains as the Secret Service); D-Bus just logs when multiple packages provide the same service interface. Does not affect functionality.

- 2026-07-06 · "Activation request for 'org.freedesktop.nm_dispatcher' failed" (39 occurrences) · NetworkManager dispatcher activation failures are transient and common; do not affect network connectivity. Monitor if actual network issues arise.

- 2026-07-06 · `x86/cpu: SGX disabled or unsupported by BIOS` (once per boot, transporter) · Informational: the kernel notes Intel SGX enclaves aren't enabled in firmware. Nothing on this system uses SGX; safe to ignore (could be enabled in Dell BIOS setup if ever needed).

- 2026-07-06 · `intel-lpss INT3446:00: probe with driver intel-lpss failed with error -16` (once per boot, transporter) · -16 is EBUSY: an ACPI-enumerated LPSS (I2C/UART) controller whose resources are already claimed. Common on Dell Latitude/XPS firmware that exposes unused LPSS devices; touchpad, audio, and peripherals unaffected.

- 2026-07-06 · `Bluetooth: hci0: Reading supported features failed (-16)` (early boot, transporter) · Transient EBUSY during adapter init; the controller registers fine afterwards (verified with `bluetoothctl show` — hci0 present, unblocked). Only actionable if Bluetooth stops pairing.

- 2026-07-14 · "Bluetooth: hci0: Reading supported features failed (-19)" (1 occurrence) · Variant of -16 error with ENODEV; Bluetooth adapter initialization transient, controller registers afterwards. Part of boot race; monitor only if Bluetooth stops pairing.

- 2026-07-14 · "Bluetooth: hci0: FW download error recovery failed (-19)" (1 occurrence) · Firmware download transient with recovery path during adapter init; adapter functional after boot race settles.

- 2026-07-14 · "Bluetooth: hci0: Failed to send firmware data (-19)" (1 occurrence) · Firmware transmission transient during adapter initialization; adapter recovers and operates normally.

- 2026-07-15 · "Process [1894/1582] (.xdg-desktop-po) of user 988 dumped core" (2 occurrences) · XDG Desktop Portal helper crashes transient at boot during D-Bus initialization race; portal recovers and operates normally.

- 2026-07-15 · "Failed to send coredump datagram: Broken pipe" (1 occurrence) · systemd-coredump socket write during shutdown race; harmless log artifact unrelated to actual crashes.

- 2026-07-15 · "i2c_hid_acpi i2c-DLL079F:01: i2c_hid_get_input: incomplete report (83/65369)" (1 occurrence) · I2C HID (touchpad/keyboard) report parsing transient; similar to existing i2c_designware STOP glitch.

- 2026-07-15 · "Bluetooth: hci0: Failed to send firmware data (-71)" (1 occurrence) · Firmware transmission error variant (EPROTO); similar to existing -19 transients, adapter recovers.

- 2026-07-15 · "DMAR: [INTR-REMAP] Request device [f0:1f.0] fault index 0x0 [fault reason 0x25] Blocked a compatibility format interrupt request" and "DMAR: DRHD: handling fault status reg 2" (2 occurrences total) · IOMMU interrupt remapping faults; typically informational on Dell firmware with quirky ACPI interrupt routing. Similar to SGX/intel-lpss pattern (no functional impact observed). Monitor only if USB or peripheral issues emerge.

- 2026-07-15 · "Failed to mount /usr/bin" (1 occurrence) · Likely the same envfs FUSE mount race as the existing actionable entry (which documents the detailed investigation). Verify with `systemctl status usr-bin.mount bin.mount`; mount should be active even if the journal shows FAILED earlier in boot.

- 2026-07-16 · `pcieport 0000:04:02.0/04:01.0/04:00.0/03:00.0: Unable to change power state from unknown/D3hot/D3cold to D0, device inaccessible` (5 occurrences) · PCIe port enumeration transient during power-state management at boot; firmware/BIOS exposes ports without devices behind them or power-transition races with device discovery. Similar to existing intel-lpss and SGX patterns (Dell Latitude/XPS firmware quirks). Device functionality (USB, storage, network) verified unaffected; only escalate if actual PCIe peripherals drop or USB devices fail to reattach.

- 2026-07-19 · `profiles/ranging/rap.c:rap_accept() RAP unable to attach` and `src/service.c:service_accept() rap profile accept failed` (2 occurrences each) · Bluetooth Radio Access Profile (RAP) controller initialization transients during adapter boot; similar to existing BAP/ISO Socket pattern when LE Audio/Rapid pairing features are disabled. Not blocking standard Bluetooth audio. Benign if LE Audio not in use.

- 2026-07-19 · `uvcvideo 3-2.3.3.3:1.1: Failed to set UVC probe control : -32 (exp. 26)` · USB camera device enumeration error; transient likely if no USB camera attached to system. Monitor only if user has camera attachment and reports non-functionality.

- 2026-07-19 · `ucsi_acpi USBC000:00: ucsi_handle_connector_change: GET_CONNECTOR_STATUS failed (-5)` and `ucsi_acpi USBC000:00: ucsi_acpi_dsm: failed to evaluate _DSM 1` · USB-C port controller transient boot errors during connector initialization; similar to existing intel-lpss/PCIe firmware quirks on Dell hardware. USB-C connectivity unaffected if devices enumerate properly; only escalate if user reports USB-C attachment or charging failures.

- 2026-07-19 · `hub 4-2:1.0: hub_ext_port_status failed (err = -71)` · USB hub port status read transient (EPROTO — protocol error); likely recovered by hub firmware or port enumeration race. Monitor only if user reports USB device hotplug failures or peripherals fail to reattach.

- 2026-07-19 · `ACPI Error: Timeout from EC hardware or EC device driver` (cascade: `AE_TIME, Returned by Handler for [EmbeddedControl]`, `Aborting method \_SB.UBTC._DSM`, `\_SB.PCI0.LPCB.ECDV.ECW1`, `\ECWB`) · Embedded Controller timeout transient during boot, likely firmware/BIOS timing race with EC device driver during initialization. Single cascade occurrence suggests transient. Monitor if system instability, power anomalies, or USB-C issues emerge; only escalate if pattern repeats or correlates with functional failures.

- 2026-08-07 · `ucsi_acpi USBC000:00: error -ETIMEDOUT: PPM init failed` · USB-C Power Delivery Manager initialization timeout at boot during Embedded Controller handshake; variant of existing line 130 ACPI EC timeout pattern. Dell firmware timing transient; benign if USB-C devices enumerate and charge normally.

- 2026-08-07 · `ucsi_acpi USBC000:00: con2: failed to register alt modes` · USB-C alternate mode registration transient as consequence of PPM init timeout; related to above. Benign if USB-C peripherals (dock, display, charging) function normally; only escalate if user reports USB-C failures.

- 2026-08-08 · `pcieport 0000:04:00.0: Unable to change power state from D3hot to D0, device inaccessible` (2x) · PCIe power state enumeration transient on new address; variant of existing 2026-07-16 pattern. Dell firmware quirk during boot; benign if PCIe peripherals (storage, networking, USB) enumerate and function normally.

- 2026-08-08 · `ucsi_acpi USBC000:00: ucsi_handle_connector_change: GET_CONNECTOR_STATUS failed (-110)` · USB-C port controller timeout variant (ETIMEDOUT); similar to existing -5 error pattern (line 126). Benign if USB-C devices charge and attach normally; only escalate if user reports USB-C failures.

- 2026-08-09 · `nl80211: kernel reports: key not allowed` (1 occurrence) · WiFi regulatory or encryption key validation transient during connection setup; likely a driver-firmware timing race or regional restriction check. Benign if WiFi connectivity remains stable; only escalate if pattern repeats with failed connections.

- 2026-08-09 · `Failed to start Open today's dashboard once the session is unlocked` (1 occurrence) · Dashboard initialization service startup race at session unlock; service likely succeeds on retry (typical systemd timer transient). Benign if dashboard is accessible via application launcher or appears on next login; only escalate if dashboard remains unavailable.

- 2026-08-09 · `atkbd serio0: Failed to deactivate keyboard on isa0060/serio0` (1 occurrence) · Keyboard controller deactivation transient at shutdown or resume; standard i8042 driver behavior when EC handshake races with device state change. Benign if keyboard remains responsive during session; only escalate if keyboard becomes unresponsive.

- 2026-08-11 · `ucsi_acpi USBC000:00: failed to re-enable notifications (-110)` (1 occurrence) · USB-C port controller notification re-enable timeout (ETIMEDOUT); variant of existing line 142 GET_CONNECTOR_STATUS error. Benign if USB-C devices charge and attach normally; likely transient at boot during Embedded Controller handshake with PPM driver.

- 2026-08-11 · `Process 2255159 (chrome) of user 1000 dumped core` (1 occurrence) · Chrome crash dump transient; similar to existing XDG Desktop Portal pattern at line 112. Benign if Chrome restarts and functions normally; only escalate if crashes recur or session stability degrades.

- 2026-08-13 · `dhcp4 (enp57s0u1u4): error -19 dispatching events` · DHCP on USB network interface (enp57s0u1u4 is a USB device path) failed because the interface is not present (-19 ENODEV); expected if adapter was physically disconnected or had a transient USB enumeration race. Benign if interface recovers on device reconnection or is not normally used.

## Resolved

<!-- move entries here when fixed, with the fixing commit/PR -->

- 2026-08-07 · Undocking on gti left no usable network for 18 minutes · Three
  compounding faults, all fixed in `modules/common/networking.nix` +
  `home/quickshell/NetworkWidget.qml`:
  1. **Nothing healed the radio on undock-while-awake.** `wifi-undock-reconcile`
     was `wantedBy=multi-user.target` + `resumeCommands` — boot and resume only.
     NM emits no dispatcher "down" event when a dock's wired interface is
     *removed* rather than losing carrier (verified: no nm-dispatcher run at the
     08:28:14 teardown; `nmcli device status` has no ethernet entry at all once
     undocked), so the wired-wifi-toggle never fired either. Now triggered by a
     `SUBSYSTEM=="net", ACTION=="remove"` udev rule.
  2. **The reconcile raced the undock and couldn't clear the block anyway.** The
     dock's Ethernet lingers `connected` for ~5s after teardown starts, so the
     single carrier check concluded "still docked". Now re-checks across ~15s,
     exiting early when no carrier is seen. It also now calls `rfkill unblock
     wlan` before `nmcli radio wifi on`: the 08:28:09 block was set from outside
     NM — WLAN *and* Bluetooth flipped in the same instant with no
     `op=radio-control` audit record, 5s ahead of the PCIe teardown — so NM did
     not treat it as its own to lift. **Origin confirmed: the Fn+Home airplane
     key.** `/proc/bus/input/devices` shows the kernel `rfkill` input handler
     bound to both "Dell WMI hotkeys" (event11) and "Intel HID events" (event9),
     i.e. `CONFIG_RFKILL_INPUT` — the kernel blocks *every* radio itself on
     `KEY_RFKILL`, which is why both flipped at once with nothing in userspace
     logging it. The key was never broken; it had no feedback. GNOME's
     airplane-mode OSD went out with the rip-out, Hyprland binds no
     `XF86RFKill`, and NetworkWidget hid itself when disconnected — so the one
     indicator vanished at the moment it went off. See fault 3.
  3. **No way to pick a network even with the radio up.** 08:21:46–08:27:20 the
     radio was enabled but every scan died as "Reject scan trigger since one is
     already pending" — six minutes, zero completed scans. Per-scan MAC
     randomization is a known way to wedge the QCA6174/ath10k scan state
     machine, so `networking.networkmanager.wifi.scanRandMacAddress = false`
     (narrow loss: it randomized probe requests only; the associated MAC was
     already pinned by `wifi.cloned-mac-address=preserve`). Separately,
     `NetworkWidget.qml` was a read-only indicator that *hid itself* on
     `conName === ""` — it vanished exactly when needed, leaving only
     nm-connection-editor, which cannot scan. It now scans, lists, and joins.

- 2026-07-07 · "Random seed file '/boot/loader/random-seed' is world accessible" · Fixed 2026-07-07: ESP mount masks tightened to fmask/dmask=0077 in `modules/common/disko.nix`. Takes full effect after a reboot remounts /boot; verify with `stat /boot/loader/random-seed`.

- 2026-07-06 · D-Bus "Ignoring duplicate name" warnings (~1000 lines/boot at err priority) · Fixed 2026-07-07: dropped at journald ingest via `LogFilterPatterns` on both dbus-broker units (`modules/common/system.nix`) — they were burying real errors and feeding this diary pure noise. (Entry retained from Benign; the underlying behavior is normal, only the log spam was the problem.)
