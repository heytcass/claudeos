# ClaudeOS - NixOS Configuration

NixOS configuration optimized for Claude Code workflow.

## Context Detection

This project has two operational contexts. Read the appropriate documentation:

**Are you helping develop/modify the NixOS configuration?**
- Working on Ubuntu dev machine
- Making changes to modules, flake.nix, or configuration
- Validating, building, or deploying changes
→ **Read [`docs/CLAUDE-DEVELOPMENT.md`](docs/CLAUDE-DEVELOPMENT.md)**

**Are you helping administer a deployed NixOS system?**
- Working on/with the live NixOS machine
- Troubleshooting running services
- Inspecting logs or system state
- Performing rollbacks or quick fixes
→ **Read [`docs/CLAUDE-OPERATIONS.md`](docs/CLAUDE-OPERATIONS.md)**

**Not sure which context?** Ask the user: "Are we working on the dev machine (Ubuntu) to build the config, or on the NixOS target machine to administer the running system?"

## CRITICAL: Ask Questions, Don't Assume

**ALWAYS use the `AskUserQuestion` tool whenever you need clarification.**

- ❌ **DO NOT make assumptions** about what the user wants
- ❌ **DO NOT guess** at implementation details or preferences
- ❌ **DO NOT assume** you know the user's intent
- ✅ **DO ask** for clarification at ANY point during development
- ✅ **DO use** the `AskUserQuestion` tool for ALL questions
- ✅ **DO stop and ask** if anything is unclear or ambiguous

**Examples of when to ask:**
- "Should I use approach A or B?"
- "Which module should this configuration go in?"
- "Do you want me to test this before committing?"
- "Should I update the documentation as well?"
- "Is this the behavior you expected?"

## Quick Reference

| Machine | IP | Purpose | Status |
|---------|-----|---------|--------|
| transporter | 10.0.10.205 | Test system | 🟢 Phase 2 complete |
| gti | TBD | Production | ⚪ Not started |

**Stack:** NixOS unstable • GNOME 49 • Wayland • Pipewire • home-manager • sops-nix

**Development Flow:** Ubuntu dev → validate → commit → deploy to NixOS target

## Documentation

All documentation is in `docs/`:
- [CLAUDE-DEVELOPMENT.md](docs/CLAUDE-DEVELOPMENT.md) - Building the configuration
- [CLAUDE-OPERATIONS.md](docs/CLAUDE-OPERATIONS.md) - Operating deployed systems
- [WORKFLOW.md](docs/WORKFLOW.md) - Detailed development workflow
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment procedures
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and fixes
- [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) - Project progress
