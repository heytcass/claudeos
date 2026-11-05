_:

{
  # fastfetch — the on-demand system fetch. Deliberately NOT run from fish's
  # interactiveShellInit: the first shell shows the daily brief and nothing
  # else (proactivity doctrine — macchina's MOTD was dropped for being a
  # spec-sheet feed). Type `fastfetch` when you want the spec sheet.
  #
  # Colors are ANSI names, not hex, so the Stylix-themed terminal palette
  # decides what they look like. Replaces the unmaintained macchina
  # (docs/plans/2026-06-12-tool-rethink.md).
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "small";
      display = {
        separator = "  ";
        color = {
          keys = "blue";
          title = "magenta";
        };
      };
      modules = [
        "title"
        "os"
        "host"
        "kernel"
        "uptime"
        "shell"
        "wm"
        "terminal"
        "cpu"
        "memory"
        "disk"
      ];
    };
  };
}
