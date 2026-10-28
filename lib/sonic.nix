# lib/sonic.nix — the sonic palette: the system's earcons, synthesised at build
# time from the same two sources as everything else it looks and moves like.
#
# The audio twin of the palette (lib/quickshell-theme.nix) and the motion
# language (lib/theme.nix `motion`):
#
#   · pitch    — each base16 accent's HUE is quantised onto a major pentatonic
#                ladder (two octaves above A3). Pentatonic means any two
#                earcons that overlap are consonant, whatever the scheme.
#   · register — a light scheme (base00 lightness > ½) sits a fourth higher.
#   · timing   — note lengths, entry staggers and the chime's swell are the
#                motion tokens (instant / quick / standard / emphasis / breathe).
#   · glide    — a gesture that moves in pitch (agent start/finish) moves along
#                a motion CURVE: the same cubic-bezier the windows and the bar
#                animate with, so the rise overshoots and settles like they do.
#
# Change the Stylix scheme or a motion token and every earcon re-tunes on the
# next rebuild. Nothing is synthesised at runtime: the output is a directory of
# WAVs, copied into the Quickshell config as `sounds/` (home/hyprland.nix) and
# played by Sonic.qml through pw-play.
#
# Timbre ("soft glass", chosen 2026-10-27): a sine plus a quiet octave
# harmonic, an eased attack, then an exponential decay over the whole note.
# Nix decides every number; pkgs/sonic-synth (Rust, fundsp) only renders the
# JSON spec built here.
{
  pkgs,
  lib,
  colors, # config.lib.stylix.colors (bare hex, no '#')
  motion, # lib/theme.nix `motion`
}:
let
  sec = ms: ms / 1000.0;
  d = motion.durations;

  # ---- palette → pitch ----------------------------------------------------
  channel = hex: i: (lib.fromHexString (builtins.substring i 2 hex)) / 255.0;
  rgb =
    hex:
    map (channel hex) [
      0
      2
      4
    ];
  hue =
    hex:
    let
      c = rgb hex;
      r = builtins.elemAt c 0;
      g = builtins.elemAt c 1;
      b = builtins.elemAt c 2;
      mx = lib.max r (lib.max g b);
      mn = lib.min r (lib.min g b);
      delta = mx - mn;
      raw =
        if delta == 0 then
          0.0
        else if mx == r then
          60.0 * ((g - b) / delta)
        else if mx == g then
          60.0 * ((b - r) / delta + 2)
        else
          60.0 * ((r - g) / delta + 4);
    in
    if raw < 0 then raw + 360.0 else raw;
  lightness =
    hex:
    let
      c = rgb hex;
    in
    (lib.foldl' lib.max 0.0 c + lib.foldl' lib.min 1.0 c) / 2;

  round = x: builtins.floor (x + 0.5);
  pentatonic = [
    0
    2
    4
    7
    9
  ];
  # Ladder degree (0..10, i.e. two octaves plus the top root) → semitones.
  degreeSemis = n: 12 * (n / 5) + builtins.elemAt pentatonic (lib.mod n 5);
  # A colour's degree: its hue around the wheel, spread over the 10 steps.
  degreeOf = hex: lib.mod (round (hue hex / 36.0)) 10;
  pitchOf = hex: degreeSemis (degreeOf hex);

  rootHz = if lightness colors.base00 > 0.5 then 293.66 else 220.0; # D4 / A3

  home = pitchOf colors.base0D; # Theme.accent — the system's own voice
  alarm = pitchOf colors.base08; # Theme.urgent

  # ---- the earcons --------------------------------------------------------
  # A note: semitones above the root, entry time, length (s), octave-harmonic
  # gain, attack (s) and the motion curve that shapes it. An optional glide
  # moves the pitch from `semis` to `to` over `glide` seconds along `curve`.
  # A sound: notes + a peak level in dBFS (each WAV is normalised to it, so
  # loudness is set here, not by how many notes overlap).
  note =
    {
      semis,
      start ? 0.0,
      dur,
      harm ? 0.3,
      attack ? sec d.instant / 6,
      attackCurve ? "standard",
      to ? null,
      glide ? null,
      curve ? null,
    }:
    {
      inherit
        semis
        start
        dur
        harm
        attack
        to
        glide
        curve
        ;
      attack_curve = attackCurve;
    };

  sounds = {
    # Rise: one tone gliding home → its fifth along `emphasized`, so it
    # overshoots and settles like a window opening. Fall: fifth → home along
    # `standard`, decelerating into place — arriving, not leaving.
    agent-start = {
      level = -6;
      notes = [
        (note {
          semis = home;
          to = home + 7;
          glide = sec d.standard;
          curve = "emphasized";
          dur = sec (d.emphasis + d.quick);
        })
      ];
    };
    agent-finish = {
      level = -6;
      notes = [
        (note {
          semis = home + 7;
          to = home;
          glide = sec d.standard;
          curve = "standard";
          dur = sec (d.emphasis + d.quick);
        })
      ];
    };

    # Notifications: one pitch (home, an octave up), timbre by urgency.
    notif-low = {
      level = -16;
      notes = [
        (note {
          semis = home + 12;
          dur = sec d.standard;
          harm = 0.0;
        })
      ];
    };
    notif-normal = {
      level = -9;
      notes = [
        (note {
          semis = home + 12;
          dur = sec d.standard;
        })
      ];
    };
    # Critical: the urgent colour's pitch with its minor third, struck twice.
    notif-critical = {
      level = -4;
      notes =
        lib.concatMap
          (
            t:
            map
              (
                s:
                note {
                  semis = s;
                  start = t;
                  dur = sec d.standard;
                  harm = 0.4;
                }
              )
              [
                (alarm + 12)
                (alarm + 15)
              ]
          )
          [
            0.0
            (sec d.standard * 0.7)
          ];
    };

    # Login: a three-note pentatonic chord from three palette hues, entering
    # a `quick` apart, each swelling in along the `breathe` curve over an
    # `emphasis` — the spark's breath.
    login = {
      level = -6;
      notes =
        lib.imap0
          (
            i: s:
            note {
              semis = s;
              start = i * sec d.quick;
              dur = sec d.breathe;
              harm = 0.25;
              attack = sec d.emphasis;
              attackCurve = "breathe";
            }
          )
          (
            lib.sort (a: b: a < b) (
              map pitchOf [
                colors.base0D
                colors.base0B
                colors.base0E
              ]
            )
          );
    };
  }
  # Level ticks for the OSD: tick-0 … tick-10 climb the ladder, so the pitch
  # IS the level. An `instant` long, with a near-zero attack — a detent.
  // lib.listToAttrs (
    map (i: {
      name = "tick-${toString i}";
      value = {
        level = -14;
        notes = [
          (note {
            semis = degreeSemis i + 12;
            dur = sec d.instant;
            harm = 0.2;
            attack = 0.003;
          })
        ];
      };
    }) (lib.range 0 10)
  );

  # ---- synthesis ----------------------------------------------------------
  spec = builtins.toJSON {
    sample_rate = 48000;
    root_hz = rootHz;
    decay_db = -48; # where a note's tail ends, below its peak
    tail = 0.05; # silence after the last note, so playback never clips it
    inherit (motion) curves;
    inherit sounds;
  };
  synth = pkgs.callPackage ../pkgs/sonic-synth { };
in
pkgs.runCommand "claudeos-sonic"
  {
    inherit spec;
    passAsFile = [ "spec" ];
  }
  ''
    ${lib.getExe synth} "$specPath" "$out"
  ''
