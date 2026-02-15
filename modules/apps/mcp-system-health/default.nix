# modules/apps/mcp-system-health — MCP server exposing system diagnostics to Claude Code.
# Registered in home/claude-code.nix as the "system-health" MCP server.
# Rewritten in bash + jq to avoid a Python runtime dependency.
{ pkgs, ... }:

let
  mcpServer = pkgs.writeScriptBin "mcp-system-health" ''
    #!${pkgs.bash}/bin/bash
    export LC_ALL=C
    export PATH="${pkgs.lib.makeBinPath [ pkgs.jq ]}:$PATH"
    ${builtins.readFile ./server.sh}
  '';
in
{
  environment.systemPackages = [ mcpServer ];
}
