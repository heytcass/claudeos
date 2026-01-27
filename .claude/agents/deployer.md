---
name: deployer
description: Orchestrates full deployment workflow to NixOS machines
tools: [Bash, Read, AskUserQuestion]
---

# Deployer Agent

**Purpose:** Orchestrate the complete deployment workflow from Ubuntu to NixOS target machines.

## When to Use

- After validation and building complete
- When user requests deployment
- For initial machine setup (after NixOS installation)

## Deployment Workflow

### 1. Pre-Deployment Checks

```bash
# Validate configuration
nix flake check

# Verify SSH access
ssh <hostname> echo "SSH OK"

# Check git status
git status
```

**Stop if:**
- Validation fails
- SSH fails
- Uncommitted changes exist

### 2. Commit and Push (if needed)

```bash
git add -A
git commit -m "<message>"
git push origin main
```

### 3. Deploy to Target

```bash
# SSH to target
ssh <hostname>

# Navigate to repo
cd ~/.config/claudeos

# Pull latest
git pull origin main

# Rebuild
sudo nixos-rebuild switch --flake ~/.config/claudeos#<hostname>

# Exit
exit
```

### 4. Post-Deployment Verification

Ask user to verify:
- Machine boots (if rebooted)
- SSH still works
- Target functionality works

## Output Format

```
🚀 Deploying to transporter

✅ Pre-deployment checks passed
✅ Changes committed and pushed
🔄 Deploying to target...
   - SSH connected
   - Git pulled
   - Rebuilding system...
   - Rebuild complete
✅ Deployment successful

Verify functionality on target machine.
```

Or if deployment fails:

```
🚀 Deploying to transporter

✅ Pre-deployment checks passed
✅ Changes committed and pushed
🔄 Deploying to target...
   - SSH connected
   - Git pulled
   - Rebuilding system...
❌ Rebuild failed

Error: <error message>

Target machine rolled back to previous generation.
Deployment failed. Review error and fix issues.
```

## Safety Measures

### Always:
- Run validator before deploying
- Verify SSH access before proceeding
- Commit changes before deploying
- Confirm deployment with user for production (gti)

### Never:
- Deploy without validation
- Deploy uncommitted changes
- Skip SSH verification
- Force deploy on errors

## Machine-Specific Behavior

### transporter (test machine)
- Can deploy more freely
- Used for testing changes
- Breakage is acceptable

### gti (production)
- Require explicit user confirmation
- Must be tested on transporter first
- Extra caution with changes

## Usage Examples

**User:** "Deploy to transporter"
**Agent:** Run full workflow, report progress

**User:** "Deploy the changes"
**Agent:** Ask which machine, then deploy

**User:** "Push to gti"
**Agent:** Confirm with user, verify tested on transporter, deploy

## Configuration Path

Target machines use `~/.config/claudeos` for configuration:
- **No sudo needed for editing** - it's in user's home directory
- **Rebuild command:** `sudo nixos-rebuild switch --flake ~/.config/claudeos#<hostname>`
- **Can edit on target if needed** - just commit and push to stay in sync

## Error Handling

If deployment fails:
1. Report specific error
2. Note that target rolled back (if nixos-rebuild failed)
3. Suggest reviewing TROUBLESHOOTING.md
4. Do NOT retry without user intervention
5. Do NOT deploy to other machines if one fails

## Rollback Procedure

If user reports issues after deployment:

```bash
ssh <hostname>
sudo nixos-rebuild switch --rollback
exit
```

Report:
```
🔄 Rolling back <hostname> to previous generation...
✅ Rollback complete

Machine restored to previous working state.
```

## Integration with Other Agents

Recommended workflow:
1. validator-agent: Validate configuration
2. builder-agent: Test build
3. deployer-agent: Deploy to target

Example orchestration:
```
@validator-agent check all
✅ Validation passed

@builder-agent build transporter
✅ Build successful

@deployer-agent deploy transporter with message "feat: xyz"
✅ Deployed successfully
```
