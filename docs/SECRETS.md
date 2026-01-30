# Secrets Management

Documentation for secrets management in ClaudeOS.

## Current Status

**ClaudeOS currently does NOT use declarative secrets management.**

All authentication is handled through:
- **OAuth/OIDC:** Chrome, Slack, Discord, VSCode extensions
- **SSH keys:** Stored in `~/.ssh/` with proper permissions (not managed declaratively)
- **Manual login:** Applications handle their own credential storage
- **User passwords:** Set during NixOS installation with `passwd`

## When to Add sops-nix

**sops-nix is a future enhancement**, not currently needed. Add it only when you have secrets that need to be IN your Nix configuration.

### Use Cases for sops-nix

Add sops-nix when you need to:
- Store API keys/tokens in service config files
- Manage database passwords in module declarations
- Configure MCP server configs with embedded credentials
- Set up Atuin sync key for cross-machine shell history
- Template credentials into declarative configuration files

### NOT Needed For

sops-nix is **NOT** needed for:
- SSH keys (already secure in `~/.ssh/` with proper permissions)
- OAuth tokens (managed by applications, not configuration)
- User passwords (manual `passwd` is simpler for 2-machine setup)
- Browser/app authentication (handled by apps themselves)
- Chrome extension credentials
- VSCode extension authentication

## Current Security Posture

### What's Secure Without sops-nix

**SSH Access:**
```bash
# SSH keys have correct permissions
ls -la ~/.ssh/
-rw------- 1 tom users    id_ed25519
-rw-r--r-- 1 tom users    id_ed25519.pub
```

**Application Credentials:**
- Stored in app-specific locations
- Protected by file permissions
- Managed by applications (Keyring, Gnome Keychain, etc.)

**Git Configuration:**
- User identity set manually (not secret)
- SSH keys for git authentication (in `~/.ssh/`)

**Firewall:**
- Enabled by default (modules/common/networking.nix)
- No ports open by default
- SSH with password auth (disable after key setup)

### Security Best Practices

**Current Configuration:**
- Root login disabled (modules/common/networking.nix)
- Firewall enabled with minimal ports
- Sudo requires password (modules/common/users.nix)
- No secrets in Git repository
- OAuth for modern applications

**Recommended Hardening:**
1. Disable SSH password authentication after key setup:
   ```nix
   services.openssh.settings.PasswordAuthentication = lib.mkForce false;
   ```

2. Set up SSH keys for deployment:
   ```nix
   users.users.tom.openssh.authorizedKeys.keys = [
     "ssh-ed25519 AAAA... your-key-here"
   ];
   ```

3. Keep sensitive files out of git (already configured):
   ```
   ~/.ssh/*
   ~/.gnupg/*
   ```

## Future: sops-nix Setup

When you're ready to add sops-nix, follow this setup guide.

### Installation

**1. Add sops-nix to flake.nix:**

```nix
# In flake.nix inputs
inputs = {
  # ... existing inputs ...
  sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

# In nixosConfiguration
modules = [
  # ... existing modules ...
  inputs.sops-nix.nixosModules.sops
];
```

**2. Install sops and age:**

```bash
# On development machine
nix-shell -p sops age
```

### Key Generation

**Generate age key:**

```bash
# Create sops directory
mkdir -p ~/.config/sops/age

# Generate key
age-keygen -o ~/.config/sops/age/keys.txt

# Get public key for .sops.yaml
age-keygen -y ~/.config/sops/age/keys.txt
```

**Output example:**
```
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### Configuration

**1. Create .sops.yaml:**

```yaml
# .sops.yaml in repository root
keys:
  - &tom age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *tom
```

**2. Create secrets file:**

```bash
# Create secrets directory
mkdir -p secrets

# Edit secrets (creates encrypted file)
sops secrets/secrets.yaml
```

**Example secrets.yaml (before encryption):**
```yaml
example_api_key: "your-secret-api-key-here"
example_password: "your-secret-password-here"
atuin_key: "your-atuin-sync-key-here"
```

### Using Secrets in Modules

**1. Enable sops in configuration:**

```nix
# In configuration.nix or a module
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/tom/.config/sops/age/keys.txt";
  };
}
```

**2. Define secrets:**

```nix
# In a module
{
  sops.secrets.example = {
    owner = "tom";
    group = "users";
    mode = "0400";
  };
}
```

**3. Reference secrets:**

```nix
# Secrets are available at runtime
{
  services.myservice = {
    enable = true;
    apiKeyFile = config.sops.secrets.example.path;
  };
}
```

**Secret paths:** `/run/secrets/<secret-name>`

### Deployment Workflow with sops-nix

**On Development Machine:**
```bash
# Edit secrets
sops secrets/secrets.yaml

# Commit encrypted secrets (safe to push)
git add secrets/secrets.yaml .sops.yaml
git commit -m "feat(secrets): add API keys"
git push
```

**On Target Machine:**
```bash
# Copy age key to target (first time only)
scp ~/.config/sops/age/keys.txt target:~/.config/sops/age/

# Deploy configuration
cd ~/.config/claudeos
git pull
sudo nixos-rebuild switch --flake .#$(hostname)

# Secrets are decrypted at runtime to /run/secrets/
```

### Key Management

**Backup Keys:**
```bash
# Backup age key (CRITICAL - store securely)
cp ~/.config/sops/age/keys.txt ~/secure-backup-location/
```

**Add New Key:**
```bash
# Generate new key
age-keygen -o ~/.config/sops/age/keys-new.txt

# Get public key
age-keygen -y ~/.config/sops/age/keys-new.txt

# Update .sops.yaml with new public key
# Re-encrypt secrets with new key
sops updatekeys secrets/secrets.yaml
```

**Rotate Secrets:**
```bash
# Edit and update secret values
sops secrets/secrets.yaml

# Git commit changes
git add secrets/secrets.yaml
git commit -m "chore(secrets): rotate API keys"

# Deploy to machines
```

### Security Considerations

**Best Practices:**
- ✅ Keep age private key out of git repository
- ✅ Backup age key securely (encrypted USB, password manager)
- ✅ Use different keys for different environments if needed
- ✅ Rotate secrets periodically
- ✅ Encrypted secrets are safe to commit to git

**Don't:**
- ❌ Commit age private key to repository
- ❌ Share age private key insecurely
- ❌ Store unencrypted secrets in repository
- ❌ Use same key for all environments in production

## Example Use Cases

When you're ready to use sops-nix, here are example scenarios:

### Atuin Sync Configuration

```nix
# Enable Atuin with sync
{
  sops.secrets.atuin_key = {
    owner = "tom";
    mode = "0400";
  };

  home-manager.users.tom = {
    programs.atuin = {
      enable = true;
      settings = {
        auto_sync = true;
        sync_address = "https://api.atuin.sh";
        key_path = config.sops.secrets.atuin_key.path;
      };
    };
  };
}
```

### MCP Server with API Keys

```nix
# Claude Desktop MCP server config
{
  sops.secrets.openai_api_key = {};

  home-manager.users.tom = {
    home.file.".config/Claude/claude_desktop_config.json".text = ''
      {
        "mcpServers": {
          "openai": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-openai"],
            "env": {
              "OPENAI_API_KEY": "$(cat ${config.sops.secrets.openai_api_key.path})"
            }
          }
        }
      }
    '';
  };
}
```

### Custom Service with Database

```nix
# Service with database password
{
  sops.secrets.db_password = {
    owner = "myservice";
    group = "users";
  };

  services.myservice = {
    enable = true;
    database = {
      passwordFile = config.sops.secrets.db_password.path;
    };
  };
}
```

## Reference

- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [sops Documentation](https://github.com/mozilla/sops)
- [age Encryption](https://github.com/FiloSottile/age)
- [NixOS Wiki: Secrets Management](https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes)

---

*Last updated: Phase 6 (Documentation & Polish)*
*Status: sops-nix is a future enhancement, not currently implemented*
