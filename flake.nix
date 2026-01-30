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
  };

  outputs = { nixpkgs, home-manager, nixos-hardware, sops-nix }@inputs:
    let
      lib = import ./lib { inherit (nixpkgs) lib; };
      specialArgs = { inherit inputs; };
    in
    {
      nixosConfigurations = {
        transporter = lib.mkSystem {
          hostname = "transporter";
          system = "x86_64-linux";
          user = "tom";
          hardwareModules = [
            nixos-hardware.nixosModules.dell-latitude-7280
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
          ];
          modules = [ ./hosts/transporter ];
          inherit specialArgs;
        };

        gti = lib.mkSystem {
          hostname = "gti";
          system = "x86_64-linux";
          user = "tom";
          hardwareModules = [
            nixos-hardware.nixosModules.dell-xps-13-9370
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
          ];
          modules = [ ./hosts/gti ];
          inherit specialArgs;
        };
      };

      # Development shell for working on this configuration
      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          nixpkgs-fmt
          statix
          deadnix
          nil
        ];
        shellHook = ''
          echo "ClaudeOS development environment"
          echo "Available commands:"
          echo "  nix flake check        - Validate configuration"
          echo "  nixpkgs-fmt .          - Format all nix files"
          echo "  statix check           - Lint for common issues"
          echo "  deadnix -e             - Find dead code"
        '';
      };
    };
}
