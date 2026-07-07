# Known Issues Ledger

Maintained by the ClaudeOS journal diary (`claudeos-journal-diary`, nightly).
Each entry: date first seen · error signature · verdict. The diary reads this
file before triaging, so anything recorded here stops generating noise.
Entries are appended by the agent; humans may prune or correct freely.
Ledger edits are committed by the normal rebuild auto-commit flow.

## Actionable

<!-- new-actionable entries land here: date · signature · next step -->

- 2026-07-07 · "Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!" (2 occurrences in 24h) · /boot mount is world-readable; the kernel randomness seed file should not be. Next step: verify /boot mount perms in `modules/common/` (likely `boot.loader` or disko config), tighten to 0750 or equivalent, rebuild and verify with `stat /boot`.

- 2026-07-06 · "Failed to start Install Claude Code CLI on first login" (31 occurrences in 24h) · The firstLogin service for Claude Code CLI installation is failing repeatedly. Next step: check `/etc/profiles/per-user/tom/` for the Claude CLI setup script, verify the installation target directory is writable, and confirm the service definition in `modules/apps/`. This blocks proper CLI integration on login.

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

- 2026-07-07 · "Skipping line 2 in filter.conf: too long" (2 occurrences in 24h) · Malformed line in audio filter config; does not affect audio functionality. Investigate if filter.conf was auto-generated or hand-edited.

- 2026-07-07 · `profiles/audio/bap.c:bap_adapter_probe() BAP requires ISO Socket which is not enabled` (2 occurrences) · Bluetooth Audio Profile (BAP) codec path logs that ISO socket support is disabled; only relevant if LE Audio pairing is intended. Not a blocker for standard Bluetooth audio.

- 2026-07-06 · D-Bus "Ignoring duplicate name" warnings (org.gnome.keyring, org.freedesktop.secrets, org.gtk.vfs.*, org.gnome.evolution.*, etc., ~200 total occurrences) · Normal in multi-package GNOME setups; D-Bus just logs when multiple packages provide the same service interface. Does not affect functionality.

- 2026-07-06 · "Activation request for 'org.freedesktop.nm_dispatcher' failed" (39 occurrences) · NetworkManager dispatcher activation failures are transient and common; do not affect network connectivity. Monitor if actual network issues arise.

- 2026-07-06 · `x86/cpu: SGX disabled or unsupported by BIOS` (once per boot, transporter) · Informational: the kernel notes Intel SGX enclaves aren't enabled in firmware. Nothing on this system uses SGX; safe to ignore (could be enabled in Dell BIOS setup if ever needed).

- 2026-07-06 · `intel-lpss INT3446:00: probe with driver intel-lpss failed with error -16` (once per boot, transporter) · -16 is EBUSY: an ACPI-enumerated LPSS (I2C/UART) controller whose resources are already claimed. Common on Dell Latitude/XPS firmware that exposes unused LPSS devices; touchpad, audio, and peripherals unaffected.

- 2026-07-06 · `Bluetooth: hci0: Reading supported features failed (-16)` (early boot, transporter) · Transient EBUSY during adapter init; the controller registers fine afterwards (verified with `bluetoothctl show` — hci0 present, unblocked). Only actionable if Bluetooth stops pairing.

## Resolved

<!-- move entries here when fixed, with the fixing commit/PR -->
