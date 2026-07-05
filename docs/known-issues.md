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
  seen once on transporter during the reinstall walk-up, clean next boot) ·
  Impact: that session lacks /usr/bin/env, so `#!/usr/bin/env` scripts fail
  until reboot. Next step if it recurs: check upstream nix-community/envfs
  for the systemd mount-handshake race; consider a restart-on-failure
  override for `usr-bin.mount`.

## Benign

<!-- known-benign noise lands here: date · signature · why it's harmless -->

## Resolved

<!-- move entries here when fixed, with the fixing commit/PR -->
