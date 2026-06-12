{
  description = "ClaudeOS - NixOS configuration optimized for Claude Code workflow";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop-linux = {
      url = "github:heytcass/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jasper = {
      url = "github:heytcass/jasper";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      sops-nix,
      disko,
      claude-desktop-linux,
      stylix,
      jasper,
      treefmt-nix,
      ...
    }@inputs:
    let
      lib = import ./lib { inherit (nixpkgs) lib; };
      specialArgs = { inherit inputs; };
      commonHardwareModules = [
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
        stylix.nixosModules.stylix
        inputs.nix-index-database.nixosModules.nix-index
        # Trace every generation back to its commit (absent attr on dirty trees)
        { system.configurationRevision = self.shortRev or "dirty"; }
      ];

      # Per-host deltas: name → nixos-hardware module. Everything else is
      # shared; hosts/<name>/ holds the rest. A host added here is also
      # registered in `checks` automatically.
      hosts = {
        # Testbed for the ClaudeOS return — see hosts/transporter/default.nix
        transporter = nixos-hardware.nixosModules.dell-latitude-7280;
        gti = nixos-hardware.nixosModules.dell-xps-13-9370;
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs (
        hostname: hardwareModule:
        lib.mkSystem {
          inherit hostname specialArgs;
          system = "x86_64-linux";
          user = "tom";
          hardwareModules = commonHardwareModules ++ [ hardwareModule ];
          modules = [ ./hosts/${hostname} ];
        }
      ) hosts;

      # Validate host configurations with `nix flake check`
      checks.x86_64-linux = builtins.mapAttrs (
        _: host: host.config.system.build.toplevel
      ) self.nixosConfigurations;

      # Formatter for `nix fmt` (treefmt-nix handles directory traversal)
      formatter.x86_64-linux =
        (treefmt-nix.lib.evalModule nixpkgs.legacyPackages.x86_64-linux {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }).config.build.wrapper;

      # Nix dev tools are installed system-wide (modules/common/system.nix)
      # No devShell needed — this is a NixOS machine
    };
}
