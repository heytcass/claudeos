# lib/keybindings.nix — THE source of truth for Claude desktop keybindings.
# Three consumers generate from this list, so everything stays in sync by
# construction:
#   home/hyprland.nix       → the actual Hyprland binds (exec or global)
#   home/claudeos-help.nix  → the `claudeos` help screen's desktop rows
#   home/hyprland.nix       → Keybinds.qml, read by CheatSheet.qml (Super+H)
#
# Fields: name, binding (GTK accelerator), display (human-readable key),
#         help (one-line description), short (compact cheat-sheet text),
#         and EITHER command (exec bind) OR global (quickshell global name).
[
  {
    name = "Claude quick terminal";
    binding = "<Super>c";
    command = "claude-quick";
    display = "Super+C";
    help = "Claude Code — coding, config, multi-step tasks";
    short = "Claude Code — coding & tasks";
  }
  {
    name = "Ask Claude";
    binding = "<Super>a";
    command = "claude-ask-desktop";
    display = "Super+A";
    help = "Quick question — popup prompt, answer as notification";
    short = "Ask — popup, answer as notification";
  }
  {
    name = "Claude screenshot analysis";
    binding = "<Super><Shift>a";
    command = "claude-screenshot";
    display = "Super+Shift+A";
    help = "Screenshot analysis — Claude reads your screen, notifies you";
    short = "Screenshot analysis";
  }
  {
    name = "Claude screenshot analysis (interactive)";
    binding = "<Super><Ctrl>a";
    command = "claude-screenshot-interactive";
    display = "Super+Ctrl+A";
    help = "Screenshot analysis — opens terminal for follow-up";
    short = "Screenshot → terminal follow-up";
  }
  {
    name = "Wish";
    binding = "<Super>w";
    global = "quickshell:wish";
    display = "Super+W";
    help = "Make a wish — describe a change in plain words; it arrives as a PR";
    short = "Make a wish — arrives as a PR";
  }
  {
    name = "Intent line";
    binding = "<Super>r";
    global = "quickshell:intent";
    display = "Super+R";
    help = "Intent line — type an app, a $command, a question?, a wish, or a task; it routes itself";
    short = "Intent line — one input, routes itself";
  }
  {
    name = "Grab text";
    binding = "<Super>t";
    command = "claude-grab-text";
    display = "Super+T";
    help = "Drag a region — any text inside it lands in the clipboard";
    short = "Grab text from a screen region";
  }
  {
    name = "Semantic clipboard";
    binding = "<Super><Shift>v";
    command = "claude-clip";
    display = "Super+Shift+V";
    help = "Transform the clipboard — fix, condense, convert, translate; result copied back";
    short = "Transform the clipboard";
  }
]
