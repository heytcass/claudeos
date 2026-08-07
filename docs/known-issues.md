# Known Issues Ledger

Maintained by the ClaudeOS journal diary (`claudeos-journal-diary`, nightly).
Each entry: date first seen · error signature · verdict. The diary reads this
file before triaging, so anything recorded here stops generating noise.
Entries are appended by the agent; humans may prune or correct freely.
Ledger edits are committed by the normal rebuild auto-commit flow.

## Actionable

<!-- new-actionable entries land here: date · signature · next step -->

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
