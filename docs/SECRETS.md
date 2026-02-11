# Secrets Management

**Complete secrets documentation will be added in Phase 5.**

This file will document:
- sops-nix setup and configuration
- Key generation and management
- Encrypting and decrypting secrets
- Using secrets in modules
- Key rotation procedures
- Backup and recovery

## Overview

ClaudeOS uses **sops-nix** with **age** encryption for secrets management.

## Quick Reference

_To be completed in Phase 5_

### Generate Age Key

```bash
# Generate key
age-keygen -o ~/.config/sops/age/keys.txt

# Get public key for .sops.yaml
age-keygen -y ~/.config/sops/age/keys.txt
```

### Encrypt Secrets

```bash
# Edit secrets (creates if doesn't exist)
sops secrets/secrets.yaml
```

### Use in Modules

```nix
# In module
sops.secrets.example = {
  sopsFile = ../secrets/secrets.yaml;
};

# Reference secret
config.sops.secrets.example.path
```

## Secrets to Manage

- [ ] Claude API key (Phase 4/5)
- [ ] Atuin sync key (Phase 3/5)
- [ ] SSH keys (if needed)
- [ ] Other application secrets

## Setup Guide

_Complete guide will be added in Phase 5_

---

_This file will be completed in Phase 5 with full sops-nix setup._
