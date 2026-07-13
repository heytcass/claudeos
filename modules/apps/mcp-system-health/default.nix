# modules/apps/mcp-system-health — MCP server exposing system diagnostics and
# runtime config validation (hyprctl / quickshell load checks) to Claude Code.
# Registered in the repo's .mcp.json as the "system-health" server (project
# scope — the ~/.claude/.mcp.json seed it once used is a path Claude Code
# never reads). Bash + jq to avoid a Python runtime dependency.
#
# Only jq is pinned onto PATH: the compositor tools (hyprctl, qs) deliberately
# resolve from the ambient session PATH so the versions always match the
# running session, and the server degrades gracefully when they're absent
# (headless lanes).
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
