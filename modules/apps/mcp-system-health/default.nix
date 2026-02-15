# modules/apps/mcp-system-health — MCP server exposing system diagnostics to Claude Code.
# Registered in home/claude-code.nix as the "system-health" MCP server.
{ pkgs, ... }:

let
  mcpServer = pkgs.writeScriptBin "mcp-system-health" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./server.py}
  '';
in
{
  environment.systemPackages = [ mcpServer ];
}
