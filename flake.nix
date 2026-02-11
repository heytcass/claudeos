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

    claude-for-linux = {
      url = "github:heytcass/claude-for-linux";
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
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, sops-nix, disko, claude-for-linux, stylix, jasper }@inputs:
    let
      lib = import ./lib { inherit (nixpkgs) lib; };
      specialArgs = { inherit inputs; };
      commonHardwareModules = [
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        disko.nixosModules.disko
        stylix.nixosModules.stylix
      ];
    in
    {
      nixosConfigurations = {
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

      # Formatter for `nix fmt`
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      # Nix dev tools are installed system-wide (modules/common/system.nix)
      # No devShell needed — this is a NixOS machine
    };
}
