# lib/keybindings.nix — THE action registry: every Claude desktop action, and
# the few that keep a key of their own. Three consumers generate from this
# list, so everything stays in sync by construction:
#   home/hyprland.nix       → the Hyprland binds (only entries with `binding`)
#   home/claudeos-help.nix  → the `claudeos` help screen's desktop rows
#   home/hyprland.nix       → Keybinds.qml: the cheat sheet's Claude rows
#                             (CheatSheet.qml, Super+H) AND the summon's action
#                             list (Summon.qml, Super+Space)
#
# One key, Super+Space, opens the summon: it launches apps and runs every
# action listed here. Only three actions keep a direct key (quick launch,
# circle to ask, point at it); the rest are reached by typing in the summon.
#
# Fields:
#   name      — the summon row's title
#   help      — one-line description (help screen, summon subtitle)
#   short     — compact text (cheat sheet)
#   command   — exec'd via `sh -c` (Hyprland bind or the summon), OR
#   global    — a quickshell GlobalShortcut name; the summon calls that
#               surface's code path directly (Summon.qml `runGlobal`)
#   binding   — optional GTK accelerator ("<Super><Shift>c") → a Hyprland bind
#   display   — human-readable key; required with `binding`
#   keywords  — words the summon matches besides the name; the FIRST is what
#               the help screen and cheat sheet tell you to type
#   icon      — a glyph name from home/quickshell/Icons.qml
#   capture   — true: the action grabs the screen, so the summon closes and
#               waits out its fade before running it (never in the capture)
#   prompt    — the summon takes text first (placeholder = this string), then
#               runs `command <text>`
#   summon    — false: not listed in the summon (the summon itself). Point at
#               it is listed but shown only while an agent has armed a pick.
#
# List order is the summon's empty-state order: most useful first.
[
  {
    name = "Summon";
    binding = "<Super>space";
    global = "quickshell:summon";
    display = "Super+Space";
    # No `$` in help text: the help screen echoes it inside fish double quotes.
    help = "Summon — launch an app or run any Claude action; also a shell command, a question?, or a task";
    short = "Summon — apps and every Claude action";
    summon = false;
  }
  {
    name = "Screenshot analysis";
    command = "claude-screenshot";
    help = "Screenshot analysis — Claude reads your screen, notifies you";
    short = "Screenshot analysis";
    keywords = [
      "screenshot"
      "screen"
      "look"
      "analyze"
    ];
    icon = "camera";
    capture = true;
  }
  {
    name = "Circle to ask";
    binding = "<Super><Shift>c";
    global = "quickshell:circle";
    display = "Super+Shift+C";
    help = "Drag a region, type a question — Claude's answer appears beside it (the region is sent to Claude)";
    short = "Circle to ask — answer beside the region";
    keywords = [
      "circle"
      "region"
      "ask about"
    ];
    icon = "crosshairs";
    capture = true;
  }
  {
    name = "Ask Claude";
    command = "claude-ask-desktop";
    help = "Quick question — the answer arrives as a notification";
    short = "Ask — answer as notification";
    keywords = [
      "ask"
      "question"
    ];
    icon = "question";
    prompt = "Ask Claude anything…";
  }
  {
    name = "Grab text";
    command = "claude-grab-text";
    help = "Drag a region — any text inside it lands in the clipboard";
    short = "Grab text from a screen region";
    keywords = [
      "grab"
      "ocr"
      "text"
      "copy text"
    ];
    icon = "font";
    capture = true;
  }
  {
    name = "Transform clipboard";
    command = "claude-clip";
    help = "Transform the clipboard — fix, condense, convert, translate; result copied back";
    short = "Transform the clipboard";
    keywords = [
      "clipboard"
      "transform"
      "fix"
      "translate"
      "condense"
    ];
    icon = "paste";
  }
  {
    name = "Shelve clipboard";
    command = "claudeos-shelve-clipboard";
    help = "Put the clipboard on the shelf — image, file, link or text, kept with the current context";
    short = "Shelve the clipboard";
    keywords = [
      "shelve"
      "keep"
      "save clipboard"
    ];
    icon = "shelf";
  }
  {
    name = "Wish";
    global = "quickshell:wish";
    help = "Make a wish — describe a change in plain words; it arrives as a PR";
    short = "Make a wish — arrives as a PR";
    keywords = [
      "wish"
      "change"
      "pr"
    ];
    icon = "magic";
  }
  {
    name = "What needs me";
    global = "quickshell:needsyou";
    help = "What needs me — the ranked queue of sessions waiting on you, failed units, PRs and cards";
    short = "What needs me — the attention queue";
    keywords = [
      "needs"
      "attention"
      "waiting"
      "queue"
    ];
    icon = "bell";
  }
  {
    name = "Open shelf";
    global = "quickshell:shelf";
    help = "Open the shelf for the current context — click to open, right-click a tile for note/move/remove";
    short = "Open the shelf";
    keywords = [
      "shelf"
      "open shelf"
    ];
    icon = "shelf";
  }
  {
    name = "Shelve region";
    command = "claudeos-shelve-region";
    help = "Drag a region — the image and the text in it go on the shelf";
    short = "Shelve a screen region";
    keywords = [
      "shelve region"
      "region"
    ];
    icon = "image";
    capture = true;
  }
  {
    name = "Screenshot to terminal";
    command = "claude-screenshot-interactive";
    help = "Screenshot analysis — opens a terminal for follow-up";
    short = "Screenshot → terminal follow-up";
    keywords = [
      "screenshot terminal"
      "screenshot"
      "interactive"
    ];
    icon = "terminal";
    capture = true;
  }
  {
    name = "Claude quick launch";
    binding = "<Super>c";
    command = "claude-quick";
    display = "Super+C";
    help = "Claude Desktop — coding, config, multi-step tasks";
    short = "Claude Desktop — coding & tasks";
    keywords = [
      "claude"
      "desktop"
      "chat"
    ];
    icon = "comment";
  }
  {
    name = "Point at it";
    binding = "<Super><Shift>p";
    global = "quickshell:pick";
    display = "Super+Shift+P";
    help = "When Claude has asked you to point at something: freeze this monitor and click the window or drag a box (nothing is captured)";
    short = "Point at it — pick what Claude asked about";
    keywords = [
      "point"
      "pick"
    ];
    icon = "eye";
    capture = true;
  }
]
