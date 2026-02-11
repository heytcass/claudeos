{ pkgs, ... }:

{
  # Install git system-wide
  environment.systemPackages = with pkgs; [
    git
    git-lfs
  ];

  # System-level git configuration (minimal)
  # User-specific configuration is in home/git.nix

  # Enable git LFS system-wide
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
