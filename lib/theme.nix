# Central theme constants — single source of truth for font and icon names
# AND the name→package pairing. Import this file from any module that needs
# theme-related values; each font's `package` is a function of pkgs so this
# file stays importable without arguments (names are plain data).
{
  # Extended palette — colors outside the base16 scheme
  # that are used across modules. Centralised here so they're
  # easy to update without grepping for hex values.
  colors = { };

  fonts = {
    monospace = {
      name = "JetBrains Mono";
      nerdName = "JetBrains Mono Nerd Font";
      package = pkgs: pkgs.nerd-fonts.jetbrains-mono;
    };
    sansSerif = {
      name = "Inter";
      package = pkgs: pkgs.inter;
    };
    # Lora is the Anthropic brand body face. It IS the system serif: document
    # and prose contexts carry the brand, while sansSerif stays Inter, which
    # was drawn for dense UI chrome. (Noto Serif remains available via
    # noto-fonts, kept in fonts.packages for its Noto Sans fallback.)
    serif = {
      name = "Lora";
      package = pkgs: pkgs.lora;
    };
    emoji = {
      name = "Noto Color Emoji";
      package = pkgs: pkgs.noto-fonts-color-emoji;
    };
    symbols = {
      name = "Symbols Nerd Font";
      fallback = "Noto Sans Symbols 2";
      package = pkgs: pkgs.nerd-fonts.symbols-only;
    };
  };
  # Anthropic brand display face. Deliberately NOT in `fonts` above: those keys
  # drive Stylix (GTK, shell, editor), and Poppins is a geometric display face
  # — legible in a headline, poor at 11px UI sizes. Installed for fontconfig so
  # locally-rendered artifacts (the morning desk dashboard) can name it for
  # headings, without it becoming the UI font.
  # The brand body face, Lora, needs no entry here: it IS `fonts.serif`.
  # See .claude/skills/brand-guidelines.
  brand = {
    display = {
      name = "Poppins";
      package = pkgs: pkgs.poppins;
    };
  };

  icons = {
    name = "Adwaita";
  };

  # Motion language — the timing twin of the palette. Hyprland (home/hyprland.nix
  # → hl.curve/hl.animation) and the bar (lib/quickshell-motion.nix →
  # Motion.qml) both read THIS, so a window settling and a pill settling move
  # on the same curve by construction. Never hardcode a duration or easing in
  # QML; reach for a token, or add one here.
  #
  # Character: calm and warm (chosen 2026-10-27). Things ease OUT — arrive
  # fast, settle slowly — and only "arrival" moments get a small overshoot.
  # Nothing bounces for its own sake: the bar is the system's one quiet voice
  # (docs/PHILOSOPHY.md), and motion is part of that voice.
  motion = {
    # Milliseconds. Hyprland's unit is 100 ms per `speed` point, so the
    # compositor divides by 100 (see home/hyprland.nix).
    durations = {
      instant = 90; # press feedback, audio-rate meters
      quick = 160; # crossfades, colour changes, small state flips
      standard = 280; # the default: size/position changes, focus
      emphasis = 480; # arrivals and departures (pills, island, wish card)
      pulse = 800; # half-cycle of an ATTENTION pulse (urgent, low battery)
      breathe = 1400; # half-cycle of an AMBIENT pulse (working, listening)
      drift = 14000; # slow decorative rotation
    };

    # Cubic beziers as [x1 y1 x2 y2] — the format both hl.curve (as two
    # points) and QML's Easing.BezierSpline (plus a trailing 1,1) take, so the
    # very same curve drives compositor and bar.
    curves = {
      standard = [
        0.22
        1
        0.36
        1
      ]; # ease-out quint: fast arrival, long gentle settle
      emphasized = [
        0.34
        1.28
        0.64
        1
      ]; # ease-out with a ~6% overshoot — arrivals only
      exit = [
        0.55
        0
        1
        0.45
      ]; # ease-in: leave quietly, accelerating away
      anticipate = [
        0.36
        0
        0.66
        (-0.4) # parenthesised: a bare `0.66 -0.4` in a list is subtraction
      ]; # ease-in with a small wind-up — "flying into the bar"
      breathe = [
        0.37
        0
        0.63
        1
      ]; # ease-in-out sine: symmetric, for pulses
    };

    # Physical springs (mass, stiffness, dampening — Hyprland's units). Damping
    # ratio ζ = dampening / (2·√(mass·stiffness)): 1 is critical (no
    # overshoot), lower rings. Hyprland takes these as-is; QML's
    # SpringAnimation runs the same ODE in fixed 16 ms Euler steps, so
    # lib/quickshell-motion.nix scales stiffness/dampening by 0.016 and the
    # bar's springs are the compositor's springs, not lookalikes.
    springs = {
      # Windows land with no visible bounce, ζ ≈ 0.97 (stock "easy" ≈ 0.78).
      settle = {
        mass = 1;
        stiffness = 180;
        dampening = 26;
      };
      # The island's width morph (clock ↔ media ↔ agent ↔ notif). Its
      # one sanctioned bounce: ζ ≈ 0.78 overshoots ~2% and settles in ~0.35 s,
      # enough that the capsule reads as elastic rather than resized.
      morph = {
        mass = 1;
        stiffness = 200;
        dampening = 22;
      };
    };

    # Hyprland-only: named animation styles, so every surface that should
    # "arrive like a window" (windows in/out, the launcher layer) shares one
    # string. QML has no equivalent — Quickshell animates contents, not shapes.
    styles = {
      popin = "popin 92%";
    };
  };
}
