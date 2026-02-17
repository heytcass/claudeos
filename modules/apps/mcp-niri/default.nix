# modules/apps/mcp-niri — MCP server exposing Niri window manager controls to Claude Code.
# Registered in home/claude-code.nix as the "niri" MCP server.
# bash + jq implementation following the mcp-system-health pattern.
{ pkgs, ... }:

let
  mcpServer = pkgs.writeScriptBin "mcp-niri" ''
    #!${pkgs.bash}/bin/bash
    export LC_ALL=C
    export PATH="${pkgs.lib.makeBinPath [ pkgs.jq ]}:/run/current-system/sw/bin:$PATH"
    ${builtins.readFile ./server.sh}
  '';
in
{
  environment.systemPackages = [ mcpServer ];
}
