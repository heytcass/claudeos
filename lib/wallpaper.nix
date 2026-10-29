# lib/wallpaper.nix — the ClaudeOS wallpaper as a pure function of the palette.
#
# Terracotta dunes under a peach moon: many windswept trails converging into
# one luminous path that climbs to the ridge, where a tiny caretaker stands —
# branches merging to main, tended by lanes. (Same scene as the old
# assets/dune.jpg, redrawn as vector art so it is sharp at any resolution.)
#
# WHY VECTOR. The old JPEG was an AI render upscaled to 3840², so every edge was
# soft. Drawing the scene here means:
#   - modules/desktop/theme.nix rasterises it with resvg → stylix.image (the
#     greeter, lock screen and hyprpaper fallback), and
#   - home/hyprland.nix ships the SVG to Quickshell, whose Wallpaper.qml lets Qt
#     rasterise it at each screen's real size and animates on top of it using
#     the geometry exported below — so the static frame and the living layer
#     cannot drift.
#
# COMPOSITION. A 1000×1000 square, because one image covers both a 1920×1080
# landscape and a 1080×1920 portrait monitor under "fill" scaling. Landscape
# shows the middle horizontal band (y ≈ 219–781), portrait the middle vertical
# band (x ≈ 219–781); everything that matters (moon, confluence, ridge,
# caretaker) lives inside that centre-safe square.
#
# `colors` is a base16 attrset of plain no-hash strings (config.lib.stylix.colors).
# Darker sand shades are made by layering base00 over a palette fill at partial
# opacity, never by inventing hex — CLAUDE.md mandate.
{ lib, colors }:
let
  c = colors;
  hex = n: "#${c.${n}}";

  # Scene geometry — exported for Wallpaper.qml as well as drawn below.
  moon = {
    x = 610;
    y = 320;
    r = 64;
  };
  confluence = {
    x = 560;
    y = 612;
  };
  lantern = {
    x = 742;
    y = 440;
  };

  pt = p: "${toString p.x} ${toString p.y}";

  # The main path: up from the bottom edge to the confluence (`mainTrail`, a
  # trail like the others, only brighter), then up the ridge to the caretaker
  # (`ridgePath`). Split so the living layer can run a pulse up any trail and
  # then on up main.
  mainTrail = "M 260 1000 C 380 860, 480 670, ${pt confluence}";
  ridgePath = "M ${pt confluence} C 630 570, 690 500, 740 454";
  mainPath = "${mainTrail} C 630 570, 690 500, 740 454";

  # Side trails fan in from the bottom edge to the confluence. Spacing and bend
  # are a deterministic wobble (no RNG in Nix — and the scene must be
  # reproducible anyway).
  trailCount = 22;
  trails = lib.genList (
    i:
    let
      x0 = -120 + i * 60;
      wob = a: b: lib.mod (i * a + b) 7;
      c1x = x0 + 80 + 10 * wob 3 1;
      c1y = 840 + 8 * wob 5 2;
      c2x = 470 + (x0 - 500) / 6 + 6 * wob 2 4;
      c2y = 690 + 4 * wob 4 3;
    in
    "M ${toString x0} 1000 C ${toString c1x} ${toString c1y}, ${toString c2x} ${toString c2y}, ${pt confluence}"
  ) trailCount;

  backRange = "M 0 560 C 150 520, 280 470, 400 470 C 520 470, 600 520, 700 515 C 800 510, 880 470, 1000 480 L 1000 1000 L 0 1000 Z";
  crest = "M 330 520 C 350 470, 420 455, 480 470 C 580 500, 670 470, 745 442 C 690 520, 600 575, 480 578 C 380 580, 315 560, 330 520 Z";
  # Drawn under the crest: its left edge hides beneath the crest so no sky
  # shows through the seam.
  shoulder = "M 745 442 C 850 455, 940 490, 1000 505 L 1000 820 L 450 820 L 450 560 C 560 540, 670 490, 745 442 Z";
  foreground = "M 0 700 C 220 640, 420 600, 560 595 C 700 592, 850 630, 1000 690 L 1000 1000 L 0 1000 Z";

  # A palette fill with a base00 shadow laid over it.
  shaded = d: fill: shade: ''
    <path d="${d}" fill="${fill}"/>
    <path d="${d}" fill="${hex "base00"}" fill-opacity="${shade}"/>
  '';

  svg = ''
    <svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" viewBox="0 0 1000 1000">
    <defs>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${hex "base00"}"/>
        <stop offset="0.55" stop-color="${hex "base01"}"/>
        <stop offset="1" stop-color="${hex "base02"}"/>
      </linearGradient>
      <radialGradient id="halo">
        <stop offset="0.4" stop-color="${hex "base09"}" stop-opacity="0.32"/>
        <stop offset="1" stop-color="${hex "base09"}" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="crest" x1="0" y1="0" x2="1" y2="0.4">
        <stop offset="0" stop-color="${hex "base0F"}"/>
        <stop offset="0.6" stop-color="${hex "base0D"}"/>
        <stop offset="1" stop-color="${hex "base08"}"/>
      </linearGradient>
      <linearGradient id="fore" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${hex "base08"}"/>
        <stop offset="1" stop-color="${hex "base0D"}"/>
      </linearGradient>
      <!-- Shoulder shadow eases from the back range's shade (0.55) at its hidden
           left edge to 0.45 on the lit ridge, so its seam never shows. -->
      <linearGradient id="shoulderShade" gradientUnits="userSpaceOnUse" x1="450" y1="0" x2="745" y2="0">
        <stop offset="0" stop-color="${hex "base00"}" stop-opacity="0.55"/>
        <stop offset="1" stop-color="${hex "base00"}" stop-opacity="0.45"/>
      </linearGradient>
      <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="2.5"/>
      </filter>
    </defs>
    <rect width="1000" height="1000" fill="url(#sky)"/>
    <circle cx="${toString moon.x}" cy="${toString moon.y}" r="${toString (moon.r * 2.4)}" fill="url(#halo)"/>
    <circle cx="${toString moon.x}" cy="${toString moon.y}" r="${toString moon.r}" fill="${hex "base09"}"/>
    ${shaded backRange (hex "base08") "0.55"}
    <path d="${shoulder}" fill="${hex "base08"}"/>
    <path d="${shoulder}" fill="url(#shoulderShade)"/>
    <path d="${crest}" fill="url(#crest)"/>
    <path d="${foreground}" fill="url(#fore)"/>
    <g fill="none" stroke="${hex "base09"}" stroke-opacity="0.4" stroke-width="0.6">
    ${lib.concatMapStringsSep "\n" (d: ''<path d="${d}"/>'') trails}
    </g>
    <path d="${mainPath}" fill="none" stroke="${hex "base09"}" stroke-width="4" filter="url(#glow)"/>
    <path d="${mainPath}" fill="none" stroke="${hex "base07"}" stroke-opacity="0.9" stroke-width="1.1"/>
    <rect x="${toString (lantern.x - 5)}" y="${toString (lantern.y + 2)}" width="2" height="10" rx="1" fill="${hex "base00"}"/>
    <circle cx="${toString lantern.x}" cy="${toString lantern.y}" r="1.6" fill="${hex "base07"}"/>
    </svg>
  '';

  # WallpaperScene.qml — the geometry above as a QML singleton, so
  # home/quickshell/Wallpaper.qml animates along exactly the drawn paths.
  # Coordinates are in the 1000-unit scene square.
  sceneQml = ''
    pragma Singleton
    import Quickshell
    import QtQuick

    // GENERATED by lib/wallpaper.nix — edit the .nix, never this file.
    Singleton {
      readonly property point moon: Qt.point(${toString moon.x}, ${toString moon.y})
      readonly property real moonRadius: ${toString moon.r}
      readonly property point confluence: Qt.point(${toString confluence.x}, ${toString confluence.y})
      readonly property point lantern: Qt.point(${toString lantern.x}, ${toString lantern.y})
      readonly property string mainTrail: "${mainTrail}"
      readonly property string ridgePath: "${ridgePath}"
      readonly property var trails: ${builtins.toJSON trails}
    }
  '';
in
{
  inherit svg sceneQml;
}
