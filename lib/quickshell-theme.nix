# lib/quickshell-theme.nix — the generator for Quickshell's `Theme.qml`
# singleton, as a pure function of the palette + font names + metrics.
#
# WHY THIS IS A SEPARATE FILE. This used to live inline in `home/hyprland.nix`,
# which is a home-manager module — so it was only reachable from Tom's user
# session. The greeter runs as the **`greeter` system user**, before any user
# session exists, and cannot see that derivation at all. Lifting the generator
# here gives both call sites one implementation:
#
#   home/hyprland.nix        → the bar
#   modules/desktop/greeter.nix → the login screen
#
# The point is that the greeter matches the bar *by construction*. A second
# hand-maintained theme mapping is exactly what the qmlgreet evaluation
# rejected (docs/plans/2026-08-15-quickshell-greeter-plan.md); reintroducing one
# here would have re-imported the problem we declined to adopt.
#
# `colors` is a base16 attrset of PLAIN no-hash strings (the shape
# `config.lib.stylix.colors` yields — available at both the NixOS and the
# home-manager level). `themeLib` is lib/theme.nix. Never hardcode hex here or
# in any consumer — CLAUDE.md mandate.
{
  colors,
  themeLib,
  edgeGap ? 4,
  barHeight ? 34,
  fontSize ? 13,
  iconSize ? 15,
  radius ? 8,
  gap ? 8,
}:
let
  c = colors;
in
''
  pragma Singleton
  import Quickshell
  import QtQuick

  // GENERATED from the Stylix base16 palette + lib/theme.nix fonts by
  // lib/quickshell-theme.nix. Both the bar and the greeter read this same
  // singleton, so the login screen and the session cannot drift apart.
  // Never hardcode hex in QML — reference these properties.
  Singleton {
    readonly property color base00: "#${c.base00}"
    readonly property color base01: "#${c.base01}"
    readonly property color base02: "#${c.base02}"
    readonly property color base03: "#${c.base03}"
    readonly property color base04: "#${c.base04}"
    readonly property color base05: "#${c.base05}"
    readonly property color base06: "#${c.base06}"
    readonly property color base07: "#${c.base07}"
    readonly property color base08: "#${c.base08}"
    readonly property color base09: "#${c.base09}"
    readonly property color base0A: "#${c.base0A}"
    readonly property color base0B: "#${c.base0B}"
    readonly property color base0C: "#${c.base0C}"
    readonly property color base0D: "#${c.base0D}"
    readonly property color base0E: "#${c.base0E}"
    readonly property color base0F: "#${c.base0F}"

    // Semantic aliases (so widgets read intent, not palette indices)
    readonly property color bg: base01
    readonly property color bgAlt: base00
    readonly property color surface: base02
    readonly property color text: base05
    readonly property color subtext: base04
    readonly property color muted: base03
    readonly property color accent: base0D
    readonly property color accentAlt: base0F
    readonly property color good: base0B
    readonly property color warn: base0A
    readonly property color urgent: base08

    // Fonts (single source of truth: lib/theme.nix)
    readonly property string fontSans: "${themeLib.fonts.sansSerif.name}"
    readonly property string fontMono: "${themeLib.fonts.monospace.nerdName}"
    readonly property int fontSize: ${toString fontSize}
    readonly property int iconSize: ${toString iconSize}

    // Metrics
    readonly property int barHeight: ${toString barHeight}
    readonly property int radius: ${toString radius}
    readonly property int gap: ${toString gap}
    // Screen-edge inset + float gap for the islands — the same value as
    // Hyprland's gaps_out, interpolated from one Nix binding.
    readonly property int edgeGap: ${toString edgeGap}
  }
''
