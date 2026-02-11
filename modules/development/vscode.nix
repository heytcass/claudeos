{ pkgs, ... }:

{
  # Install VSCode system-wide
  environment.systemPackages = with pkgs; [
    vscode
  ];

  # Note: VSCode is an unfree package
  # allowUnfree is already configured in modules/common/nix.nix

  # Enable VSCode system integration
  programs.vscode = {
    enable = true;
  };

  # User-specific extensions and settings are in home/vscode.nix
}
