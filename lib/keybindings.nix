# lib/keybindings.nix — THE source of truth for Claude desktop keybindings.
# home/gnome.nix generates the dconf custom-keybinding entries from this list
# and home/claudeos-help.nix generates the help screen's desktop rows from it.
# Add a binding here; both stay in sync by construction.
#
# Fields: name (dconf), binding (GTK accelerator, dconf), command (dconf),
#         display (human-readable key), help (one-line description)
[
  {
    name = "Claude quick terminal";
    binding = "<Super>c";
    command = "claude-quick";
    display = "Super+C";
    help = "Claude Code — coding, config, multi-step tasks";
  }
  {
    name = "Ask Claude";
    binding = "<Super>a";
    command = "claude-ask-desktop";
    display = "Super+A";
    help = "Quick question — popup prompt, answer as notification";
  }
  {
    name = "Claude screenshot analysis";
    binding = "<Super><Shift>a";
    command = "claude-screenshot";
    display = "Super+Shift+A";
    help = "Screenshot analysis — Claude reads your screen, notifies you";
  }
  {
    name = "Claude screenshot analysis (interactive)";
    binding = "<Super><Ctrl>a";
    command = "claude-screenshot-interactive";
    display = "Super+Ctrl+A";
    help = "Screenshot analysis — opens terminal for follow-up";
  }
  {
    name = "Semantic clipboard";
    binding = "<Super><Shift>v";
    command = "claude-clip";
    display = "Super+Shift+V";
    help = "Transform the clipboard — fix, condense, convert, translate; result copied back";
  }
]
