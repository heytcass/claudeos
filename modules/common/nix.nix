{ lib, ... }:

{
  # Enable flakes and nix-command
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Store Nix config under XDG directories instead of ~/.nix-*
    use-xdg-base-directories = true;

    # Optimize store automatically
    auto-optimise-store = true;

    # Suppress "Git tree is dirty" warning during builds
    warn-dirty = false;

    # Disable global flake registry lookups
    flake-registry = "";

    # Keep build outputs and derivations for faster rebuilds
    keep-outputs = true;
    keep-derivations = true;

    # Trusted users for nix commands
    trusted-users = [
      "root"
      "@wheel"
    ];

    # Substituters and keys for faster builds
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # nh: modern nixos-rebuild front-end — live build graph (nom), automatic
  # closure diff on every switch, and declarative GC (replaces nix.gc.automatic)
  programs.nh = {
    enable = true;
    flake = "/home/tom/.config/claudeos";
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 14d";
    };
  };

  # comma + prebuilt nix-index database: `, foo` runs any program from nixpkgs
  # without installing it — trace-free experimentation. The database refreshes
  # with the weekly flake update. Replaces the sqlite command-not-found handler.
  programs.nix-index-database.comma.enable = true;
  programs.command-not-found.enable = false;

  # Trigger GC early if disk space is low (bytes)
  nix.settings.min-free = 1073741824; # 1 GiB — start GC when free space drops below this
  nix.settings.max-free = 5368709120; # 5 GiB — stop GC once this much space is reclaimed

  # Allow unfree packages (Chrome, VSCode, etc.)
  nixpkgs.config.allowUnfree = true;

  # Set system state version (mkDefault so a host installed later can pin its own)
  system.stateVersion = lib.mkDefault "24.11";
}
