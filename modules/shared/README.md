# Shared baseline

Host-agnostic NixOS modules used by claudeos's own hosts **and** by a private
fleet flake that consumes this directory as an inputless subflake:

```nix
inputs.claudeos-shared.url = "github:<owner>/claudeos?dir=modules/shared";
imports = [ inputs.claudeos-shared.nixosModules.default ];
```

The design and migration order are in
`docs/plans/2026-10-29-shared-common-modules-plan.md`.

## The contract

Every file in this directory must keep these rules. CI enforces the first
three; review enforces the rest.

1. **Self-contained.** Nothing here references a path outside this directory
   (`../`, `lib/`, `assets/`). Consumers fetch this directory, not the repo's
   layout.
2. **No specialArgs.** claudeos passes `user` and `inputs`; other consumers
   don't. Anything a module needs from its host comes through options under
   `claude-os.shared.*`.
3. **Plain NixOS only.** No home-manager, Stylix, or other third-party module
   options. Every module must evaluate on a bare `nixpkgs.lib.nixosSystem` —
   the `shared-headless` check in the root flake builds exactly that.
4. **`lib.mkDefault` for anything a consumer may disagree with.** A setting is
   unconditional only when both consumers already set it identically and
   would treat divergence as a bug.
5. **Never shared:** `system.stateVersion`, firewall openings (including
   `services.openssh.openFirewall`), SSH authorized-key lists, and anything
   naming a host, address, domain, or secret. This repo is public.
6. **Changes reach machines claudeos doesn't own.** A behaviour change here
   says so in its PR title and lists the expected diff; a pure move must leave
   every host's closure unchanged. Self-heal PRs touching this directory never
   auto-merge.
