---
name: brand-guidelines
description: Applies Anthropic's brand colors and typography to code artifacts in this repo — HTML dashboards, generated pages, docs. Use when styling anything that should carry the ClaudeOS/Anthropic look. Adapts the chat-oriented brand skill to a codebase where colors come from Stylix base16 tokens, never hardcoded hex.
---

# Anthropic Brand Styling — in code

Adapted from the chat `brand-guidelines` skill, which targets slide decks via
python-pptx and hands out raw hex. **Neither assumption holds here.** In this
repo colors arrive as base16 tokens from Stylix, and artifacts are HTML.

## The one rule that overrides the upstream skill

CLAUDE.md: *"Always use Stylix/base16 palette references — never hardcode hex
color values."*

The brand hexes below are the **reference the palette was derived from**, not
values to paste. Emit `var(--base0D)`, not `#d97757`. Source of truth at
runtime is `~/.config/stylix/palette.json`; at Nix eval time it is
`config.lib.stylix.colors.withHashtag`.

## Color — and which brand source wins

There are **two** Anthropic color sources, and they disagree. The upstream skill
carries the *deck* palette. This system's scheme (`modules/desktop/theme.nix`)
was extracted from **live claude.ai CSS tokens** — a more specific, product-
accurate source.

**Decided: the claude.ai tokens win.** Do not "correct" the palette toward the
deck hexes. They describe the same identity at lower resolution.

| Brand role | Deck hex | Token | This system | Note |
|---|---|---|---|---|
| Light (text on dark) | `#faf9f5` | `base05` | `#faf9f5` | exact match |
| Orange (primary accent) | `#d97757` | `base0D` | `#d97757` | exact match — `--accent-brand` |
| Dark (background) | `#141413` | `base00` | `#1f1e1d` | `--bg-200` wins |
| Green (tertiary) | `#788c5d` | `base0B` | `#8a9a6b` | olive; `base0B` wins |
| Blue (secondary) | `#6a9bcc` | `base0C` | `#2c84db` | `--accent-secondary-100` wins |
| Mid Gray | `#b0aea5` | `base04` / `base03` | `#c2c0b6` / `#9c9a92` | brackets it |
| Light Gray (subtle bg) | `#e8e6dc` | — | — | no equivalent in a dark scheme |

Consequences you must respect:

- **Orange is the primary accent, and it is exact.** Spend it sparingly — one
  accent per view. It is the single strongest brand signal available.
- **`base0C` is a vivid blue, not the deck's muted one.** Use it for small marks
  (thin bars, dots, strokes) where saturation reads as precision. Never as a
  large fill — it goes loud next to the warm neutrals.
- **There is no Light Gray.** Subtle backgrounds come from `base01`/`base02`.
- Accent *cycling* (orange → blue → green) is an upstream slide-deck behavior.
  Do not cycle. Pick the accent that means something; gray the rest.

## Typography

| Role | Face | Stack |
|---|---|---|
| Headings / display | Poppins | `"Poppins", "Inter", system-ui, sans-serif` |
| Body prose | Lora | `"Lora", Georgia, serif` |
| Numerals, axes, UI chrome | Inter | `"Inter", system-ui, sans-serif` |

**Lora is the system serif.** `lib/theme.nix` → `fonts.serif` points Stylix at
it, so documents and prose contexts carry the brand face desktop-wide.

**Poppins is installed but is not a UI font.** It lives in `lib/theme.nix` →
`brand.display`, pulled into `fonts.packages` by `modules/desktop/fonts.nix`.
It is a geometric display face: right for a headline, poor at 11px. Pointing
`fonts.sansSerif` at it would restyle GNOME Shell, titlebars, and notifications
in a face never drawn for that job. Inter keeps the UI. Name Poppins only in an
artifact's own CSS, for headings.

Two hard constraints:

- **Never fetch a webfont.** Generated pages open as `file://` and are specified
  self-contained. A Google Fonts `@import` fails silently and you get Arial.
  Because the faces are in fontconfig, naming them in CSS is enough.
- **Verify before relying on a face:** `fc-list | grep -i poppins`. If it comes
  back empty the system hasn't been rebuilt since the font was added.

## Where this collides with `dataviz` — and who wins

Load both skills for a chart. Where they disagree, **`dataviz` wins on marks and
figures; brand wins on prose.**

- *Serif body text* is brand. But `dataviz` forbids a serif on the **hero
  figure** ("reads as off-brand decoration"). So: Lora for prose, Inter for the
  big number, axis ticks, and any tabular column.
- *Text never wears the data color.* Brand orange on a temperature line is
  correct; brand orange on the label next to it is not. Labels take
  `base05`/`base04`/`base03`.
- *`tabular-nums` only in columns* — never on a large standalone number.
- Status colors (`base08` warn, `base0B` ok) are reserved for state. They are
  not "accent 3," regardless of what the upstream accent-cycling section says.

## Motion

Not in the upstream skill; the house style for generated pages:

- Entrance: a short staggered rise (`opacity` + `translateY`), ~70ms apart.
- Hover: a 2px lift plus a soft shadow. Never a color flip.
- **Always** guard with `@media (prefers-reduced-motion: reduce)` — animation
  and transition off, and any `stroke-dashoffset` draw-on resolved to its
  final state, not left mid-draw.

## Checklist

1. No `#rrggbb` anywhere in the artifact's source. (`rgb(0 0 0 / .5)` for a
   shadow is fine — that's an alpha, not a brand color.)
2. `:root` tokens injected from Stylix, not typed by hand.
3. Poppins for headings, Lora for prose, Inter for numbers.
4. Exactly one accent carries meaning; everything else is neutral.
5. `prefers-reduced-motion` honored.
6. Open the file and look at it before calling it done.
