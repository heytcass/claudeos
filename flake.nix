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
    in
    {
      nixosConfigurations = {
        # Testbed for the ClaudeOS return — see hosts/transporter/default.nix
        transporter = lib.mkSystem {
          hostname = "transporter";
          system = "x86_64-linux";
          user = "tom";
          hardwareModules = commonHardwareModules ++ [
            nixos-hardware.nixosModules.dell-latitude-7280
          ];
          modules = [ ./hosts/transporter ];
          inherit specialArgs;
        };

        gti = lib.mkSystem {
          hostname = "gti";
          system = "x86_64-linux";
          user = "tom";
          hardwareModules = commonHardwareModules ++ [
            nixos-hardware.nixosModules.dell-xps-13-9370
          ];
          modules = [ ./hosts/gti ];
          inherit specialArgs;
        };
      };

      # Validate host configurations with `nix flake check`
      checks.x86_64-linux = {
        transporter = self.nixosConfigurations.transporter.config.system.build.toplevel;
        gti = self.nixosConfigurations.gti.config.system.build.toplevel;
      };

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
