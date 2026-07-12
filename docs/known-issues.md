# Known Issues Ledger

Maintained by the ClaudeOS journal diary (`claudeos-journal-diary`, nightly).
Each entry: date first seen · error signature · verdict. The diary reads this
file before triaging, so anything recorded here stops generating noise.
Entries are appended by the agent; humans may prune or correct freely.
Ledger edits are committed by the normal rebuild auto-commit flow.

## Actionable

<!-- new-actionable entries land here: date · signature · next step -->

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

- 2026-07-11 · health-check exit 1 triggered solely by `kernel: watchdog: watchdog0: watchdog did not stop!` (single crit line caught by the "Critical Log Entries" 15-min lookback) · Reboot artifact, not a live fault: the Intel iTCO hardware watchdog can't be halted cleanly on shutdown, so the kernel logs this at crit priority as the last line before the next boot (observed 14:12:39, fresh kernel up 14:13:08). The first post-boot health check's 15-min window swept it up and exited 1 — expected on any reboot, and unavoidable on a day with many rebuilds (7 boots on 2026-07-11). `alert-context.txt` held only this line; no failed services, disk, memory, OOM, or stale-update issues. Distinct from the by-design "health-check failed" entry (2026-07-08) — this documents the specific benign *trigger content*. Only escalate if the watchdog line appears mid-session (not adjacent to a reboot) or the new kernel fails to come up.

- 2026-07-11 · "Module [libstdc++.so.6, libgcc_s.so.1, libgbm.so.1, libdrm.so.2, libzstd.so.1, libxml2.so.16, libX11.so.6, libpango-1.0.so.0, libreadline.so.8, etc.] without build-id" (100+ occurrences) · Debugger-metadata warnings: libraries lack ELF build-id sections used for symbol matching. Informational only and does not affect runtime. Normal in NixOS where build-id inclusion varies by package; no action needed.

- 2026-07-09 · "Failed to start ClaudeOS Claude-authored notification handler" (35 occurrences) · Expected: the notifier is triggered by health-check `OnFailure=`, so it runs once per health-check failure. The notifier "failing" in the journal is the normal exit; the actual notification (if any) is the only actionable part.

- 2026-07-09 · "Failed to start ClaudeOS morning system briefing" (1 occurrence) · Likely transient or timer not yet fired (scheduled service runs once daily). Monitor if pattern continues.

- 2026-07-08 · "Failed to start ClaudeOS system health check" (periodic) · BY DESIGN — the health check deliberately exits 1 when it finds issues, because `OnFailure=claudeos-notify.service` is how the notifier gets triggered (see the script header in `modules/apps/claude-monitor/health-check.sh`). A "failed" health-check unit means the check WORKED and found something; the something is what deserves attention, not the unit. Do not "fix" the exit code.

- 2026-07-08 · Chrome thread futex/pthread waits (64 syscall_cancel, 33 futex_abstimed_wait, 22 pthread_cond_wait, etc. over 24h) · Normal thread synchronization in Chrome's multi-threaded event loop; condition-variable and futex waits are expected. No actual failure signaled.

- 2026-07-08 · "ELF object binary architecture: AMD x86-64" (4 occurrences) · Informational kernel or tooling message; this system is indeed x86-64. No issue.

- 2026-07-07 · "Failed to start Install Claude Code CLI on first login" / repeated `claude-code-installer` skip lines (~31/24h) · REFUTED as a failure (runtime audit 2026-07-07): these are `ConditionPathExists=!~/.local/bin/claude` **skips** — the CLI is already installed and self-updating (v2.1.203). The one real failure (2026-07-05, `curl: command not found`) self-resolved 17 minutes later. Do not "fix" the installer.

- 2026-07-07 · user services restarting during `nixos-rebuild switch` (claudeos-* timers/units bouncing mid-activation) · If observed, this is home-manager issue #7583 (user services erroneously restarted during activation when HM runs as a NixOS module) — an upstream bug, not a config regression. Don't chase it here; check the issue's status instead.

- 2026-07-07 · "Skipping line 2 in filter.conf: too long" (2 occurrences in 24h) · Malformed line in audio filter config; does not affect audio functionality. Investigate if filter.conf was auto-generated or hand-edited.

- 2026-07-07 · `profiles/audio/bap.c:bap_adapter_probe() BAP requires ISO Socket which is not enabled` (2 occurrences) · Bluetooth Audio Profile (BAP) codec path logs that ISO socket support is disabled; only relevant if LE Audio pairing is intended. Not a blocker for standard Bluetooth audio.

- 2026-07-06 · D-Bus "Ignoring duplicate name" warnings (org.gnome.keyring, org.freedesktop.secrets, org.gtk.vfs.*, org.gnome.evolution.*, etc., ~200 total occurrences) · Normal in multi-package setups providing the same D-Bus interface (gnome-keyring remains as the Secret Service); D-Bus just logs when multiple packages provide the same service interface. Does not affect functionality.

- 2026-07-06 · "Activation request for 'org.freedesktop.nm_dispatcher' failed" (39 occurrences) · NetworkManager dispatcher activation failures are transient and common; do not affect network connectivity. Monitor if actual network issues arise.

- 2026-07-06 · `x86/cpu: SGX disabled or unsupported by BIOS` (once per boot, transporter) · Informational: the kernel notes Intel SGX enclaves aren't enabled in firmware. Nothing on this system uses SGX; safe to ignore (could be enabled in Dell BIOS setup if ever needed).

- 2026-07-06 · `intel-lpss INT3446:00: probe with driver intel-lpss failed with error -16` (once per boot, transporter) · -16 is EBUSY: an ACPI-enumerated LPSS (I2C/UART) controller whose resources are already claimed. Common on Dell Latitude/XPS firmware that exposes unused LPSS devices; touchpad, audio, and peripherals unaffected.

- 2026-07-06 · `Bluetooth: hci0: Reading supported features failed (-16)` (early boot, transporter) · Transient EBUSY during adapter init; the controller registers fine afterwards (verified with `bluetoothctl show` — hci0 present, unblocked). Only actionable if Bluetooth stops pairing.

## Resolved

<!-- move entries here when fixed, with the fixing commit/PR -->

- 2026-07-07 · "Random seed file '/boot/loader/random-seed' is world accessible" · Fixed 2026-07-07: ESP mount masks tightened to fmask/dmask=0077 in `modules/common/disko.nix`. Takes full effect after a reboot remounts /boot; verify with `stat /boot/loader/random-seed`.

- 2026-07-06 · D-Bus "Ignoring duplicate name" warnings (~1000 lines/boot at err priority) · Fixed 2026-07-07: dropped at journald ingest via `LogFilterPatterns` on both dbus-broker units (`modules/common/system.nix`) — they were burying real errors and feeding this diary pure noise. (Entry retained from Benign; the underlying behavior is normal, only the log spam was the problem.)
