# sops-nix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire up sops-nix declarative secrets for Jasper's Anthropic API key and prepare Atuin sync.

**Architecture:** sops-nix decrypts `secrets/secrets.yaml` at NixOS activation time using age. Jasper reads the API key via `ANTHROPIC_API_KEY` env var (its built-in fallback). No runtime SOPS tooling on PATH.

**Tech Stack:** NixOS, sops-nix, age, SOPS

**Design doc:** `docs/plans/2026-02-14-sops-nix-design.md`

---

### Task 1: Create .sops.yaml

**Files:**
- Create: `.sops.yaml`

**Step 1: Create the SOPS creation rules file**

```yaml
keys:
  - &gti age1a7znzdjx0fm4rx9jcd63r5tdaajpxthwgqplx87xyfrmal2pge2qcln96z

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *gti
```

**Step 2: Verify the file is tracked by git**

The `.gitignore` already allows `secrets/.sops.yaml` but `.sops.yaml` at root is not ignored. Verify:

Run: `git check-ignore .sops.yaml || echo "Not ignored (good)"`
Expected: "Not ignored (good)"

**Step 3: Commit**

```bash
git add .sops.yaml
git commit -m "feat(secrets): add .sops.yaml creation rules for gti age key"
```

---

### Task 2: Create encrypted secrets file

**Files:**
- Create: `secrets/secrets.yaml`

**Step 1: Create secrets directory**

Run: `mkdir -p secrets`

**Step 2: Decrypt the Jasper API key to get the plaintext value**

Run: `nix shell nixpkgs#sops -c sops -d /home/tom/Projects/jasper/secrets.yaml`
Expected: YAML output showing `services.anthropic_api_key: sk-ant-...` (the actual key)

**Step 3: Create the new secrets file with sops**

Run: `nix shell nixpkgs#sops -c sops secrets/secrets.yaml`

This opens an editor. Enter:

```yaml
jasper_anthropic_api_key: <paste the key from step 2>
atuin_key: placeholder-add-real-key-later
```

Save and exit. SOPS encrypts the file.

**Step 4: Verify encryption**

Run: `head -5 secrets/secrets.yaml`
Expected: Should show `jasper_anthropic_api_key: ENC[AES256_GCM,data:...` (encrypted)

**Step 5: Verify decryption**

Run: `nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml`
Expected: Shows plaintext YAML with both keys

**Step 6: Commit**

```bash
git add secrets/secrets.yaml
git commit -m "feat(secrets): add encrypted secrets (Jasper API key + Atuin placeholder)"
```

---

### Task 3: Create secrets.nix module

**Files:**
- Create: `modules/common/secrets.nix`
- Modify: `modules/common/default.nix:4-12`

**Step 1: Create the secrets module**

```nix
# modules/common/secrets.nix
{ ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/tom/.config/sops/age/keys.txt";
  };

  sops.secrets.jasper_anthropic_api_key = {
    owner = "tom";
    mode = "0400";
  };

  sops.secrets.atuin_key = {
    owner = "tom";
    mode = "0400";
  };
}
```

**Step 2: Import in modules/common/default.nix**

Add `./secrets.nix` to the imports list (after `./system.nix`):

```nix
{ ... }:

{
  imports = [
    ./boot.nix
    ./disko.nix
    ./nix.nix
    ./users.nix
    ./networking.nix
    ./locale.nix
    ./system.nix
    ./secrets.nix
  ];
}
```

**Step 3: Verify the build**

Run: `nix build .#nixosConfigurations.gti.config.system.build.toplevel --dry-run`
Expected: No errors (dry-run shows derivation would build)

**Step 4: Commit**

```bash
git add modules/common/secrets.nix modules/common/default.nix
git commit -m "feat(secrets): add sops-nix secrets module with Jasper + Atuin declarations"
```

---

### Task 4: Update Jasper to use sops-nix secret

**Files:**
- Modify: `modules/apps/jasper.nix:1-47`

**Step 1: Update jasper.nix**

Replace the full file with:

```nix
{ config, pkgs, inputs, ... }:

let
  jasperPkgs = inputs.jasper.packages.${pkgs.system};
in
{
  # Install daemon and COSMIC applet system-wide
  environment.systemPackages = [
    jasperPkgs.daemon
    jasperPkgs.cosmic-applet
  ];

  # D-Bus service for socket activation
  services.dbus.packages = [
    (pkgs.writeTextFile {
      name = "jasper-dbus-service";
      text = ''
        [D-BUS Service]
        Name=org.jasper.Daemon
        Exec=${jasperPkgs.daemon}/bin/jasper-companion-daemon start
      '';
      destination = "/share/dbus-1/services/org.jasper.Daemon.service";
    })
  ];

  # User systemd service — auto-starts after graphical session
  systemd.user.services.jasper-companion = {
    description = "Jasper AI Companion Daemon";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "jasper-start" ''
        export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets.jasper_anthropic_api_key.path})
        exec ${jasperPkgs.daemon}/bin/jasper-companion-daemon start
      ''}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
```

Key changes:
- Added `config` to function args (needed for `config.sops.secrets`)
- Removed `path = [ pkgs.sops pkgs.age ]`
- Removed `environment.JASPER_SOPS_PATH`
- ExecStart now uses a wrapper script that reads the sops-nix secret into ANTHROPIC_API_KEY

**Step 2: Verify the build**

Run: `nix build .#nixosConfigurations.gti.config.system.build.toplevel --dry-run`
Expected: No errors

**Step 3: Commit**

```bash
git add modules/apps/jasper.nix
git commit -m "feat(jasper): use sops-nix secret instead of runtime SOPS decryption"
```

---

### Task 5: Update Atuin config comment

**Files:**
- Modify: `home/shell/cli-tools.nix:78-81`

**Step 1: Update the Atuin comment**

Change lines 78-81 from:

```nix
    settings = {
      # Don't sync to cloud (will configure in Phase 5 with secrets)
      auto_sync = false;
      sync_address = "";
```

To:

```nix
    settings = {
      # Sync disabled — enable after adding real atuin_key to secrets/secrets.yaml
      # and setting key_path = config.sops.secrets.atuin_key.path
      auto_sync = false;
      sync_address = "";
```

**Step 2: Commit**

```bash
git add home/shell/cli-tools.nix
git commit -m "docs(atuin): update comment to reference sops-nix secret"
```

---

### Task 6: Update documentation

**Files:**
- Modify: `docs/SECRETS.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`

**Step 1: Update SECRETS.md**

Replace the header section (lines 1-17) with updated status reflecting sops-nix is now active. Update the "Current Status" to show sops-nix is implemented for Jasper + Atuin placeholder. Keep the reference sections intact.

**Step 2: Update IMPLEMENTATION_STATUS.md**

Change the sops-nix line from:
```
- [ ] sops-nix for declarative secrets management (currently using runtime SOPS/age workaround for Jasper)
```
To:
```
- [x] sops-nix for declarative secrets management
```

**Step 3: Commit**

```bash
git add docs/SECRETS.md docs/IMPLEMENTATION_STATUS.md
git commit -m "docs: update secrets and status docs for sops-nix implementation"
```

---

### Task 7: Full build + deploy + test

**Step 1: Format**

Run: `nix fmt`

**Step 2: Check**

Run: `nix flake check`
Expected: No errors

**Step 3: Build**

Run: `nixos-rebuild build --flake /home/tom/.config/claudeos#gti`
Expected: Build succeeds

**Step 4: Apply (requires user confirmation)**

Run: `sudo nixos-rebuild switch --flake /home/tom/.config/claudeos#gti`
Expected: Activation succeeds, secrets decrypted to /run/secrets/

**Step 5: Verify secrets exist**

Run: `ls -la /run/secrets/`
Expected: `jasper_anthropic_api_key` and `atuin_key` files with owner tom, mode 0400

Run: `cat /run/secrets/jasper_anthropic_api_key | head -c 10`
Expected: First 10 chars of the Anthropic API key (sk-ant-...)

**Step 6: Restart Jasper and verify**

Run: `systemctl --user restart jasper-companion && sleep 2 && systemctl --user status jasper-companion`
Expected: Active (running), no errors about missing API key

**Step 7: Push**

Run: `git push`
Expected: All commits pushed to origin
