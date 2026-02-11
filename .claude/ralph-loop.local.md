---
active: true
iteration: 1
max_iterations: 10
completion_promise: "All three graphical fixes are implemented and the NixOS configuration builds successfully"
started_at: "2026-02-01T21:35:00Z"
---

## Task: Fix Three Graphical Rendering Issues on COSMIC Desktop

### Context
We're running NixOS with COSMIC desktop, Ghostty terminal (GTK4/libadwaita), and Stylix theming. Three visual glitches need fixing.

### Issue 1: Broken "new tab" icon in Ghostty tab bar
**Symptom:** The "new tab" button in Ghostty's GTK tab bar shows a broken image / "image not found" placeholder instead of the `tab-new-symbolic` icon.
**Root cause:** GTK icon theme is set to `Papirus-Dark` (in `modules/desktop/cosmic.nix`). On COSMIC (unlike GNOME), Adwaita symbolic icons aren't automatically in the icon lookup path even though `adwaita-icon-theme` is installed as a system package (in `modules/desktop/cosmic-system.nix`). The Papirus theme inherits from `hicolor`, not `Adwaita`, so libadwaita's symbolic icon fallback doesn't resolve.
**Fix approach:** Ensure Adwaita symbolic icons are discoverable. Options: (a) add fontconfig/GTK settings to include Adwaita as icon fallback, (b) set `XDG_DATA_DIRS` to include system icon paths, (c) use `environment.sessionVariables` or dconf to configure icon inheritance. Research what NixOS COSMIC users do to solve this.

### Issue 2: Claude Code pause icon renders as color emoji
**Symptom:** The ⏸ (U+23F8) pause icon shown in Claude Code's plan mode renders as a color emoji glyph instead of a monochrome terminal glyph from JetBrains Mono Nerd Font.
**Root cause:** System-level `fonts.fontconfig.defaultFonts.emoji = ["Noto Color Emoji"]` in `modules/desktop/fonts.nix` creates global fontconfig rules that classify codepoints in the Miscellaneous Technical block (U+2300-U+23FF) as emoji, routing them to Noto Color Emoji before Ghostty's font-family stack is consulted.

### Issue 3: Green star in Claude Code working animation
**Symptom:** In Claude Code's "thinking" spinner animation (growing star), one of the star sizes renders as green instead of the terracotta color used by the terminal theme.
**Root cause:** Same as Issue 2 — certain star codepoints (likely in Miscellaneous Symbols U+2600-U+26FF or Dingbats U+2700-U+27BF) are being rendered by Noto Color Emoji with inherent color, overriding the terminal's foreground color.

### Fix approach for Issues 2 & 3
Add fontconfig rules (via `fonts.fontconfig.localConf` in `modules/desktop/fonts.nix`) that prioritize `Symbols Nerd Font` (from `nerd-fonts.symbols-only`, already installed) over `Noto Color Emoji` for the specific Unicode ranges used by terminal UI glyphs. This prevents fontconfig from routing those codepoints to the color emoji font while still allowing actual emoji (U+1F300+) to use Noto Color Emoji.

Also add `"Symbols Nerd Font"` to the `defaultFonts.monospace` chain so fontconfig considers it for monospace contexts before falling back to emoji.

### Key files to modify
- `modules/desktop/fonts.nix` — add fontconfig localConf rules and update defaultFonts.monospace
- `modules/desktop/cosmic.nix` or `modules/desktop/cosmic-system.nix` — fix icon theme fallback
- `home/ghostty.nix` — possibly add `"Symbols Nerd Font"` to font-family chain

### Validation
After changes, run the validator agent and builder agent to confirm the configuration builds. Stage new files before validation (flakes require tracked files).
