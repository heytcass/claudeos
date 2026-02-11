{ ... }:

{
  # Phase 3: Applications
  imports = [
    ./terminals.nix
    ./browsers.nix
    ./communication.nix
    ./claude.nix # Phase 4: Claude Code CLI
  ];
}
