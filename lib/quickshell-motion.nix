# lib/quickshell-motion.nix — the generator for Quickshell's `Motion.qml`
# singleton, as a pure function of lib/theme.nix's `motion` tokens.
#
# The timing twin of lib/quickshell-theme.nix: Theme.qml is the palette,
# Motion.qml is the tempo. Hyprland reads the very same tokens (home/hyprland.nix
# → hl.curve/hl.animation), so a pill settling in the bar and a window settling
# on screen share one curve by construction.
#
# Usage in QML (a bezier needs both lines — Easing.BezierSpline reads the curve
# from `bezierCurve`):
#
#   NumberAnimation {
#       duration: Motion.standard
#       easing.type: Easing.BezierSpline
#       easing.bezierCurve: Motion.curveStandard
#   }
#
# Never hardcode a duration or easing in QML — add a token to lib/theme.nix.
{ lib, motion }:
let
  inherit (motion) durations curves;
  json = builtins.toJSON;
  cap = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;
  # QML's BezierSpline wants [x1, y1, x2, y2, endX, endY]; the end is (1, 1).
  spline =
    p:
    json (
      p
      ++ [
        1
        1
      ]
    );
  # Joined with the body's indent, NOT prefixed with it: an interpolation at
  # column 0 of the '' string defeats Nix's indentation stripping and pushes
  # `pragma Singleton` off line-start (see .claude/rules/quickshell-qml.md).
  durationProps = builtins.concatStringsSep "\n  " (
    map (n: "readonly property int ${n}: ${toString durations.${n}}") (builtins.attrNames durations)
  );
  curveProps = builtins.concatStringsSep "\n  " (
    map (n: "readonly property var curve${cap n}: ${spline curves.${n}}") (builtins.attrNames curves)
  );
in
''
  pragma Singleton
  import Quickshell
  import QtQuick

  // GENERATED from lib/theme.nix `motion` by lib/quickshell-motion.nix.
  // Hyprland's hl.curve/hl.animation read the same tokens, so the bar and the
  // compositor move as one. Edit the .nix, never this file.
  //
  // Character: calm and warm. Arrive fast, settle slowly; overshoot only on
  // arrivals (curveEmphasized); pulses breathe symmetrically (curveBreathe).
  Singleton {
    // Durations, ms. `pulse` and `breathe` are HALF a cycle (one leg of a
    // there-and-back SequentialAnimation).
    ${durationProps}

    // Cubic beziers for `easing.type: Easing.BezierSpline`.
    ${curveProps}
  }
''
