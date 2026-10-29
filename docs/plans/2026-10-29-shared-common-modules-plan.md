# Shared common module layer — plan

*Drafted 2026-10-29. Plan only: no module code moves in the PR that adds this
file. Decisions marked **(decided)** were made by the owner on 2026-10-29;
everything else is a recommendation open to review.*

## The question this answers

ClaudeOS is not the owner's only NixOS flake. A second, **private** flake (the
"fleet flake" below) runs a handful of headless home servers plus one small
rented VPS relay. The question was whether to merge every host into one
configuration. The answer was **no**, for four reasons:

| | claudeos | fleet flake |
|---|---|---|
| Visibility | public | private |
| Shape | desktop: home-manager, Stylix, Hyprland, Quickshell, btrfs | headless: ZFS, libvirt, sops per host, no home-manager |
| Update cadence | weekly auto-update, auto-applied behind a VM boot gate | weekly lock PR, deployed by hand, per host |
| Blast radius | one laptop at a time | the house's always-on services |

What the two *do* share is a small host-agnostic baseline — nix daemon
settings, locale, the one human account, sshd hardening — currently written
twice and already drifting. This plan extracts that baseline into one place.

**Direction is fixed: claudeos → fleet, never the reverse.** The fleet flake's
own module index already says so: its host-agnostic modules "could one day be
imported *from* claudeos … never the reverse, and nothing host-specific ever
goes upstream." claudeos is public, so the shared layer can contain nothing
that names a fleet host, address, domain, service or secret.

---

## 1. Inventory

Concrete diff of `modules/common/` (claudeos) against the fleet flake's
`modules/`, setting by setting.

### 1a. Shared — same intent, near-identical text

| Concern | claudeos | fleet | Verdict |
|---|---|---|---|
| `nix.settings.experimental-features` | `nix-command flakes` | same | **share** |
| `nix.settings.trusted-users` | `root @wheel` | same | **share** |
| `nix.settings.substituters` / `trusted-public-keys` | cache.nixos.org + nix-community | same (fleet comment: "mirrors the laptop's list") | **share** |
| `nix.settings.warn-dirty` / `flake-registry` | `false` / `""` | same | **share** |
| `nix.channel.enable` | `false` | same | **share** |
| `nix.optimise.{automatic,dates}` | weekly | weekly | **share** |
| `nixpkgs.config.allowUnfree` | `true` | `true` | leave per consumer (a policy, not a baseline) |
| `time.timeZone` | `mkDefault` America/New_York | same | **share** (`mkDefault`) |
| `i18n.defaultLocale` | en_US.UTF-8 | same | **share** |
| `console.keyMap` | colemak | colemak | **share** |
| `programs.fish.enable` | yes | yes | **share** |
| `security.sudo.enable = false` + `security.sudo-rs.enable` | yes | yes | **share** |
| `security.sudo-rs.wheelNeedsPassword` | `mkDefault true` | derived from "does this host have a console password in sops" | share the `mkDefault true`; fleet keeps its override |
| `users.users.<name>.{isNormalUser,shell,linger}` | fish, linger | fish, linger | **share** behind an option for the name |
| `hardware.enableRedistributableFirmware` | `true` | `true` (VPS `mkForce false`) | **share** as `mkDefault true` |
| `services.openssh` (password auth off, root login no) | yes | yes | **share** |
| base CLI set (vim, htop, pciutils, usbutils, dnsutils) | in a 400-line `system.nix` | in `base.nix` | **share** the five-package intersection |

### 1b. Diverged on purpose — share the mechanism, not the value

| Concern | claudeos | fleet | Resolution |
|---|---|---|---|
| sshd crypto | Kex/Ciphers/MACs allowlist | none | **(decided)** union: allowlist goes shared |
| `KbdInteractiveAuthentication` | unset | `false` | **(decided)** union: `false` shared |
| `services.openssh.hostKeys` | default (RSA + ed25519) | ed25519 only — the fleet's sops-nix age identity *is* this key | **(decided)** union: ed25519-only shared. The path must stay `/etc/ssh/ssh_host_ed25519_key` exactly, or fleet secrets stop decrypting. Laptops lose an RSA host key no client uses. |
| sshd firewall | `openFirewall = false`, 22 opened explicitly | default `openFirewall = true` | **not shared.** The shared module sets nothing firewall-related. One fleet host (the VPS relay) deliberately closes 22 to the internet after bootstrap; a shared default that opened it would be a silent exposure. Each consumer decides. |
| authorized SSH keys | 3 keys | 1 different key | **not shared.** Key lists are an option with **no default**; each consumer passes its own. Which machines may reach which hosts is a per-flake decision. |
| `users.users.<name>.extraGroups` | wheel + networkmanager, video, audio, dialout, kvm | wheel | shared module sets `wheel` only; consumers add the rest |
| `users.mutableUsers` | (default, true) | `false` | fleet-only |
| GC | `programs.nh.clean` (keep 5 / 14d) | `nix.gc` (14d) | not shared; `nh`'s `flake` path is laptop-specific |
| nix daemon scheduling | default | `daemonCPUSchedPolicy`/`daemonIOSchedClass = "idle"` | fleet-only (builds run on the servers) |
| `system.stateVersion` | `mkDefault "24.11"` | `mkDefault "26.11"` | **never shared** — a shared default would silently re-state every host that relies on it |
| `system.configurationRevision` | `self.shortRev or "dirty"` | `self.rev or null` | per flake (it reads the consumer's own `self`) |
| sops | one `secrets/secrets.yaml`, host SSH key | `secrets/<host>.yaml` gated on `pathExists`, host SSH key | not shared: file paths live in each repo. The *convention* (host ed25519 key as age identity) is guaranteed by the shared `hostKeys` setting above. |
| journal cap | none | `services.journald.settings.Journal.SystemMaxUse = "1G"` | candidate for wave 2 (both would benefit), not wave 1 |

### 1c. Desktop-only (stays in claudeos `modules/common/` or `modules/desktop/`)

Auto-update + VM smoke gate, self-heal, generation labels, Claude helpers,
snapper/btrfs snapshots and scrub, NetworkManager + dock/wifi reconcile,
resolved with DoT, scx scheduler, dbus-broker, oomd, envfs, zram, power
management (thermald, power-profiles-daemon, upower), Intel graphics,
systemd-boot settings, the polkit `manage-units` rule, `nix-index` + comma,
`use-xdg-base-directories`, `keep-outputs`/`keep-derivations`, `min-free`/`max-free`.

Self-heal and auto-update deserve a note: they *look* like fleet candidates
("self-heal/journal patterns"), but the fleet's authority model forbids an
agent from merging or deploying without the owner's yes. Both lanes assume
the opposite. They stay claudeos-only; if the fleet ever wants them, it
writes its own lane against its own authority rules.

### 1d. Server-only (stays in the fleet flake)

ZFS root support (LTS kernel pin, `services.zfs.autoScrub`, trim), the
second-disk LUKS+ZFS module, disk-health reporting (ZFS + SMART → an external
webhook with a heartbeat), UPS client shutdown, the service-account module,
per-host hardware profiles, networkd, `daemon*Sched*` idle builds,
`users.mutableUsers = false`, the bench installer.

Disk-health is the one honest wave-2 candidate: the laptop has no SMART
watching either. It would need its sink made pluggable (webhook vs.
`notify-send`/journal-diary) before it could move, and it is ZFS-shaped today.
Scheduled as wave 2 in §5, after the baseline has settled on both sides.

### 1e. Hardening — claudeos-only for now

`boot.kernel.sysctl` hardening, `security.auditd`/`security.audit.rules`,
`systemd-boot.editor = false`. All sensible on servers, but adopting them
changes fleet behaviour, not just where the text lives, so it is not part of
the wave-1 extraction. It is wave 2 (§5): the owner's standing preference is
DRY — standardise whatever can honestly be shared — so every setting both
sides *should* have is in scope, each as an intended, reviewed change.

---

## 2. Interface

### 2a. Where it lives **(decided: inputless subflake)**

```
modules/shared/
  flake.nix         # inputs = { }; outputs = { nixosModules = … }
  flake.lock        # trivial (no inputs)
  default.nix       # imports every module below → nixosModules.default
  nix.nix
  locale.nix
  user.nix
  ssh.nix
  base-tools.nix
  README.md         # the contract (rules below), for both consumers
```

- `modules/shared/flake.nix` has **no inputs**. Its only outputs are
  `nixosModules.{default,nix,locale,user,ssh,base-tools}` — attribute sets of
  plain module files. No `pkgs`, no `lib` from an input: modules receive those
  from the consumer's own `nixpkgs`, like any NixOS module.
- The fleet consumes it as `github:<owner>/claudeos?dir=modules/shared`. Its
  lock gains **one** node. Using the root flake instead would pull claudeos's
  32-node lock (home-manager, Stylix, the Claude desktop flake, nix-index,
  mcp-nixos, treefmt, …) into the fleet lock, and the fleet's deploy script
  runs `nix flake archive --to ssh://<host>`, which copies **every** locked
  input to every server. A zero-input subflake makes that impossible by
  construction rather than by a growing list of `follows = ""` nulls.
- **One source of truth:** claudeos's own `modules/common/default.nix` imports
  `../shared` by path. Both consumers evaluate the same files. claudeos's root
  flake may re-export `nixosModules = (import ./modules/shared/flake.nix).outputs { }`
  for discoverability, but nothing depends on that.

Cost noted: `?dir=` still fetches the whole claudeos source tree (≈13 MB today,
11 MB of it `assets/`) as one store path per pinned revision. Acceptable; if
it ever isn't, the remedy is moving wallpapers out, not changing the shape.

### 2b. Self-containment rules (enforced in CI, §4)

1. No path in `modules/shared/` may reference anything outside it
   (`../`, `lib/`, `assets/`). A `?dir=` subflake *can* reach its parent today,
   but that is exactly the coupling that breaks silently later.
2. No `specialArgs` dependence. claudeos passes `user` and `inputs` as
   specialArgs; the fleet passes only `inputs`. Shared modules use **options**,
   never specialArgs.
3. No home-manager, Stylix, or any option that only exists when a third-party
   module is imported. A shared module must evaluate on bare `nixpkgs.lib.nixosSystem`.
4. Every value that one consumer may disagree with is `lib.mkDefault`.
   Unconditional settings are only those both sides already set identically
   *and* would treat as a bug to diverge on (e.g. `PasswordAuthentication = false`).
5. Nothing host-specific, nothing private. The repo is public.

### 2c. Option namespace

`claude-os.shared.*` — extends the existing `claude-os.*` namespace (used by
`claude-os.autoUpdate`, `claude-os.selfHeal`) instead of inventing a third
alongside the fleet's `homeOps.*`. Proposed surface, deliberately small:

```nix
claude-os.shared = {
  enable = mkEnableOption …;          # default true when nixosModules.default is imported
  user = {
    name = mkOption { type = str; };                 # no default — consumer must say
    description = mkOption { type = str; default = ""; };
    authorizedKeys = mkOption { type = listOf str; };  # no default — consumer must say
  };
};
```

Everything else in the shared modules is plain config with `mkDefault`, so
the consumer's ordinary option assignments override it. No per-module enable
flags in wave 1: a consumer that does not want a concern imports
`nixosModules.<concern>` selectively instead of `default`.

Every option name the shared modules will set was checked on 2026-10-29
against the nixpkgs that claudeos currently pins (`nix eval` over
`nixosConfigurations.gti.options`), and the non-obvious ones against the
`nixos` MCP server: `nix.settings`, `nix.channel.enable`,
`nix.optimise.{automatic,dates}`, `time.timeZone`, `i18n.defaultLocale`,
`console.keyMap`, `programs.fish.enable`, `security.sudo.enable`,
`security.sudo-rs.{enable,wheelNeedsPassword}`,
`users.users.<name>.linger`, `services.openssh.{settings,hostKeys,openFirewall}`,
`hardware.enableRedistributableFirmware`, `services.journald.settings`
(wave 2; present in the pin, not yet in the MCP index),
`virtualisation.vmVariant`, and `pkgs.testers.runNixOSTest` (noogle).
Re-verify at implementation time; nixpkgs moves.

---

## 3. Consumption (fleet side)

```nix
# fleet flake.nix
inputs.claudeos-shared.url = "github:<owner>/claudeos?dir=modules/shared";
# no `follows` needed: the subflake has no inputs to follow
```

```nix
# fleet modules/default.nix
imports = [ inputs.claudeos-shared.nixosModules.default … ];
claude-os.shared.user = { name = "…"; authorizedKeys = [ … ]; };
```

- **No `inputs.nixpkgs.follows`** — there is no nixpkgs input to follow. The
  shared modules evaluate against the fleet's own nixpkgs, which is the point:
  one nixpkgs per fleet host, chosen by the fleet.
- **Pin bumps on the fleet's schedule.** The fleet's weekly lock workflow
  updates a named list of inputs (`nix flake update nixpkgs sops-nix disko`)
  and deliberately holds others back. `claudeos-shared` joins the
  *held-back* list: it moves only via `nix flake update claudeos-shared` in a
  PR of its own, so a shared-layer change is never mixed with a nixpkgs bump in
  one diff. Optionally a monthly reminder; never automatic.
- **Version signal.** claudeos tags shared-layer releases (`shared-vN`) when
  the interface changes, and the fleet may pin `?ref=shared-vN&dir=…`
  instead of a branch. **(decided)** The fleet pins plain commits (its lock
  already does) until the first breaking interface change; from then on it
  pins `shared-vN` tags, so a rename is something it opts into by name.

---

## 4. CI and gates

### 4a. claudeos CI — catching what it can't see

claudeos CI has never seen a fleet host and never will (private). It can
build a **stand-in** that has the fleet's *shape* without any of its content:

1. **`checks.x86_64-linux.shared-headless`** (in claudeos's root flake, which
   has nixpkgs): a `nixosSystem` importing *only* `modules/shared` plus a
   minimal host — networkd, `users.mutableUsers = false`, GRUB, no
   home-manager, no Stylix, `hardware.enableRedistributableFirmware = mkForce false`
   (the VPS shape), firewall with 22 closed. Built for real in `validate.yml`'s
   `host-build` job. Catches: a shared module that leaks a desktop dependency,
   reads a specialArg, or fails without a third-party module.
2. **`checks.x86_64-linux.shared-vm`**: `pkgs.testers.runNixOSTest` booting
   that stand-in. Asserts: `multi-user.target` reached, zero failed units,
   sshd answers with an **ed25519 host key only**, password auth refused, the
   configured user exists with fish as shell and linger on, `sudo` is sudo-rs,
   `nix show-config` contains the shared substituters, and **port 22 is not
   open** (proving the shared layer never touches the firewall). GitHub-hosted
   Linux runners expose KVM; if a run finds none, the job fails rather than
   skipping — a gate that silently skips is worse than no gate.
3. **Interface snapshot**: a check that dumps the option tree under
   `claude-os.shared` (names + types) to JSON and diffs it against a committed
   `modules/shared/interface.json`. A rename or removal then shows up as a
   reviewable diff to that file, labelled "breaking for the fleet".
4. **Self-containment lint**: `grep` in `validate.yml` refusing `../`,
   `specialArgs`-only names (`user`, `inputs`), and `home-manager`/`stylix`
   inside `modules/shared/`.
5. **Rung-2 protection (decided)**: `modules/shared/` joins the heal
   auto-merge protected paths (`heal-automerge.yml`'s forbidden-path regex,
   and its allowlist comment). A self-heal PR touching it always waits for a
   human. See §6 for the PHILOSOPHY.md consequence.

### 4b. Pure-refactor gate (claudeos, each extraction PR)

Moving text must not change behaviour. For each extraction PR, dump the
affected config subtrees before and after and require an empty diff:

```bash
nix eval --json .#nixosConfigurations.<host>.config.nix.settings      # etc.
nix store diff-closures <old-toplevel> <new-toplevel>                  # must be empty
```

(Comparing toplevel `drvPath`s alone does not work: `configurationRevision`
embeds the commit, so every commit changes it.) PRs that *intend* a behaviour
change — the SSH union — say so in their title and list the expected diff.

### 4c. Fleet-side validation of a bump

In the fleet repo, per `claudeos-shared` bump PR:

1. `nix flake update claudeos-shared` alone.
2. `nix flake check --no-build` (the fleet's rule; plain `check` compiles GPU
   stacks on the laptop).
3. Dry-run toplevel for every host; `nix store diff-closures` per host against
   the currently deployed generation. Expected diff = only what the claudeos
   changelog promised. Anything else blocks.
4. Deploy least-critical host first with `test`, then `switch`; the host that
   runs the house last; the VPS relay last of all (§5). Deploys stay the
   owner's, per the fleet's authority rules.

---

## 5. Migration order

Each step is one PR, builds green on its own, and is smallest-risk first.
Steps 1–6 are claudeos-only; nothing reaches the fleet until step 7.

| # | Repo | Change | Risk | Gate |
|---|---|---|---|---|
| 1 | claudeos | Create `modules/shared/` subflake skeleton (empty `default.nix`, README contract), `shared-headless` check, self-containment lint, rung-2 protected path, **PHILOSOPHY.md update** (§6). claudeos hosts don't import it yet. | none | gti/transporter closures unchanged |
| 2 | claudeos | Move **locale** (tz, locale, keymap) into `shared/locale.nix`; `modules/common/locale.nix` keeps only `extraLocaleSettings` + console font. | trivial | pure-refactor gate |
| 3 | claudeos | Move the **nix settings** intersection (§1a) into `shared/nix.nix`; laptop extras stay in `modules/common/nix.nix`. | low | pure-refactor gate |
| 4 | claudeos | **User** module with `claude-os.shared.user.*` options; claudeos passes `user` specialArg value + its key list into the option; groups beyond wheel stay laptop-side. Add `shared-vm` test. | low | pure-refactor gate + VM test |
| 5 | claudeos | **base-tools** intersection. | trivial | pure-refactor gate |
| 6 | claudeos | **sshd** union (decided): allowlist + kbd-interactive off + ed25519-only host keys. *Intended* behaviour change on laptops: RSA host key no longer offered. Update `interface.json`; tag `shared-v1`. | low–medium | VM test; check laptop↔laptop SSH both directions after switch |
| 7 | fleet | Add `claudeos-shared` input (held back from weekly updates). Import **only `nixosModules.locale`** on the least-critical server. | trivial | diff-closures empty |
| 8 | fleet | `locale` fleet-wide via `modules/default.nix`; delete the duplicated lines from its base module. | trivial | diff-closures empty on every host |
| 9 | fleet | `nix`, then `base-tools`, then `user` — one PR each, duplicated lines deleted. `wheelNeedsPassword` override and `mutableUsers` stay fleet-side. | low | diff-closures; deploy least-critical first |
| 10 | fleet | `ssh` — the one intended behaviour change for servers (crypto allowlist). The client that matters is the primary laptop (gti), which already runs the same allowlist as a server, so negotiation is expected to work; any other client still in use gets the same check *before* merge. ed25519 host-key path unchanged, so sops keeps decrypting. | medium | `ssh -vv` from gti against one host on `test`; then roll |
| 11 | fleet | **VPS relay** last: it is too small to evaluate the flake, so its closure is built on another machine and copied in. Same diff-closures check, built off-box. Confirm the relay's port-22 posture is unchanged (the shared layer must not touch it — the VM test in claudeos asserts this). Keep its out-of-band console in reach for the first boot. | medium (remote, no physical access) | diff-closures; first boot watched |
| 12 | both | **Wave 2 — journald cap:** move the fleet's `SystemMaxUse` into `shared/journald.nix` as `mkDefault`. Intended change on laptops (journal capped). | low | claudeos VM test; fleet diff-closures empty |
| 13 | both | **Wave 2 — hardening:** move claudeos's sysctl + auditd rules into `shared/hardening.nix`, each knob `mkDefault`. Before the fleet adopts it, check every sysctl against what the servers need (VM hosts and routers need forwarding; containers may need unprivileged namespaces) and override there rather than weakening the shared default. | medium | `shared-vm` test; fleet `test` deploy, least-critical first |
| 14 | both | **Wave 2 — disk health:** generalise the fleet's ZFS+SMART module into `shared/disk-health.nix` with a pluggable sink (webhook on servers, desktop notification/journal on laptops) and a btrfs path alongside ZFS. Largest wave-2 item; its own short design doc first. | medium | stand-in host with a fake sink; laptop sees a test alert |
| — | ongoing | Anything else that turns out identical on both sides moves the same way: one concern per PR, pure-refactor gate for moves, explicit diff for changes. | | |

Rollback at every step is the NixOS one: previous generation on the host,
`git revert` in the repo, and on the fleet side simply not bumping the pin.

---

## 6. Risks, and what changes in PHILOSOPHY.md

### Risks

- **Invisible consumer.** claudeos CI can't build fleet hosts. Mitigations:
  stand-in host + VM test (§4a), pure-refactor gate (§4b), the fleet's own
  held-back pin and diff-closures review (§4c). Residual: a fleet host that
  combines a shared default with something only it has (ZFS, GRUB) in a way the
  stand-in doesn't mimic. Accepted; caught at the fleet's dry-run.
- **nixpkgs skew.** claudeos tests shared modules against claudeos's nixpkgs;
  the fleet evaluates them against its own. Both track nixos-unstable, but
  their pins move on different days. An option renamed upstream between the
  two pins breaks one side first. Mitigation: shared modules use only
  long-stable options; the fleet's bump PR catches the rest at eval.
- **Silent-default creep.** A future shared setting without `mkDefault`, or a
  new default (e.g. `stateVersion`), changes every fleet host on its next bump.
  The README contract and §2b rule 4 forbid it; diff-closures on the fleet
  side is the backstop.
- **Firewall exposure via sshd.** The one dangerous default in this space is
  `services.openssh.openFirewall` (NixOS default `true`). The shared module
  must leave it alone; the VM test asserts 22 stays closed on a host that
  closed it. If a later change sets it, the VPS relay's internet-facing
  posture is what breaks.
- **sops identity.** The fleet's secrets decrypt with the ed25519 host key at
  `/etc/ssh/ssh_host_ed25519_key`. Any shared change to `hostKeys` that moves
  or drops that path locks every fleet host out of its secrets on next boot.
  Called out in `shared/ssh.nix` and asserted by the VM test.
- **Public visibility of the baseline.** The shared layer makes the fleet's
  sshd/nix/user baseline readable by anyone. It is generic and contains no
  keys, names or addresses (keys stay consumer-side), so this is accepted.
- **Self-heal reach.** Without protection, a one-file heal PR under
  `modules/shared/` could auto-merge and later ride a fleet bump. Closed by
  the decided rung-2 protection.

### PHILOSOPHY.md — conclusions this changes (explicitly)

These edits belong in **step 1's PR**, the first one that creates
`modules/shared/` (per CLAUDE.md: change a conclusion, update the document in
the same PR). This plan-only PR does not edit PHILOSOPHY.md because nothing in
the repo changes behaviour yet.

1. **The rung-2 window** (constitution). Its justification is "everything
   inside it is cheap to be wrong about … one module file cannot alter the
   boot path, the disk layout, the secrets". A file under `modules/shared/`
   *can* reach machines claudeos does not own and cannot test. So
   `modules/shared/` joins the protected paths in item 3, and the reasoning
   paragraph gains one line: a module with downstream consumers is not cheap
   to be wrong about, whatever its size.
2. **"What ClaudeOS is"** gains a sentence: claudeos is also the upstream of a
   small shared baseline consumed by a private fleet flake; the direction is
   one-way and nothing host-specific or private flows upstream.
3. **Security posture (decided trade-offs)** gains a scope note: those
   trade-offs (passwordless `manage-units`, no FDE, loose Claude-tooling
   supply chain) are decided *for the single-user laptop*. They are never
   carried into the shared layer; the shared layer holds only settings both
   flakes chose independently.

Unchanged: the two-ring rule (shared modules are ring 1 on both sides), the
blast-radius rule (the fleet's pin is the window and the rollback trigger),
the cost doctrine (no new LLM calls), the proactivity doctrine.

---

## Answered questions (2026-10-29)

1. **SSH clients for the fleet:** mostly gti. Step 10's check is `ssh -vv`
   from gti, plus any other client still in use.
2. **Tagging:** commit pins until the first breaking change, then `shared-vN`
   tags (§3).
3. **Wave 2:** yes. The owner prefers DRY, so whatever can be standardised
   should be: journald cap, hardening and disk health are steps 12–14 in §5.
