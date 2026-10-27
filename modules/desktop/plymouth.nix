# Boot splash — the Claude spark breathing on base00 (chosen 2026-10-27).
#
# Plymouth came back once its price was re-measured: +7MB on the scripted
# initrd (51.0 → 58.1MB), not the ~60-90MB that kept it out under the old
# systemd-initrd (see modules/common/boot.nix). The theme is ours rather than
# Stylix's: Stylix's target spins a logo, and the spark should breathe on the
# same rhythm as the bar's agent glow (lib/theme.nix motion.durations.breathe),
# so boot, greeter and session share one pulse.
#
# Nothing per-generation is baked in (no label, no version): the theme package
# is then identical across rebuilds and the initrd dedups on the ESP.
{
  config,
  pkgs,
  ...
}:
let
  themeLib = import ../../lib/theme.nix;
  c = config.lib.stylix.colors;
  rgb = n: "${c."${n}-dec-r"}, ${c."${n}-dec-g"}, ${c."${n}-dec-b"}";

  # Plymouth's script plugin redraws at 50 Hz, so a half-cycle of `breathe`
  # ms is this many frames.
  breatheFrames = themeLib.motion.durations.breathe / 20;

  script = builtins.toFile "claudeos.script" ''
    cx = Window.GetWidth() / 2;
    cy = Window.GetHeight() / 2;

    Window.SetBackgroundTopColor(${rgb "base00"});
    Window.SetBackgroundBottomColor(${rgb "base00"});

    // The spark is ~11% of the screen height, whatever the panel; the halo
    // image carries a 50% transparent border, so it is drawn at twice that.
    size = Math.Int(Window.GetHeight() * 0.11);
    spark.image = Image("spark.png").Scale(size, size);
    halo.image = Image("halo.png").Scale(size * 2, size * 2);

    halo.sprite = Sprite(halo.image);
    halo.sprite.SetPosition(cx - size, cy - size, 0);
    spark.sprite = Sprite(spark.image);
    spark.sprite.SetPosition(cx - size / 2, cy - size / 2, 1);

    // Breathing: a raised cosine, one leg per `breathe` half-cycle — the
    // same ease-in-out sine the bar's curveBreathe approximates.
    frame = 0;
    breathing = 1;

    fun refresh_callback() {
      if (breathing) {
        frame++;
        b = 0.5 - 0.5 * Math.Cos(Math.Pi * frame / ${toString breatheFrames});
        spark.sprite.SetOpacity(0.6 + 0.4 * b);
        halo.sprite.SetOpacity(0.15 + 0.55 * b);
      }
    }
    Plymouth.SetRefreshFunction(refresh_callback);

    // Prompts (a LUKS passphrase, fsck questions): hold the spark still and
    // lit, text below it in base05.
    text_y = cy + size;
    prompt = null;
    bullets = null;
    question = null;
    answer = null;
    message = null;

    fun hold() {
      breathing = 0;
      spark.sprite.SetOpacity(1);
      halo.sprite.SetOpacity(0.4);
    }

    fun centered(image, y) {
      s = Sprite(image);
      s.SetPosition(cx - image.GetWidth() / 2, y, 2);
      return s;
    }

    fun password_callback(prompt_text, bullet_count) {
      hold();
      prompt = centered(Image.Text(prompt_text, ${rgb "base05"}), text_y);
      dots = "";
      for (i = 0; i < bullet_count; i++) dots += "•";
      bullets = centered(Image.Text(dots, ${rgb "base05"}), text_y + 32);
    }
    Plymouth.SetDisplayPasswordFunction(password_callback);

    fun question_callback(prompt_text, entry) {
      hold();
      question = centered(Image.Text(prompt_text, ${rgb "base05"}), text_y);
      answer = centered(Image.Text(entry, ${rgb "base05"}), text_y + 32);
    }
    Plymouth.SetDisplayQuestionFunction(question_callback);

    fun message_callback(text) {
      message = centered(Image.Text(text, ${rgb "base03"}), Window.GetHeight() * 0.85);
    }
    Plymouth.SetMessageFunction(message_callback);

    fun normal_callback() {
      prompt = null;
      bullets = null;
      question = null;
      answer = null;
      breathing = 1;
    }
    Plymouth.SetDisplayNormalFunction(normal_callback);
  '';

  # The spark, recoloured from the asset's alpha onto base0D, plus a blurred
  # copy for the halo. Colours come from Stylix — no hex in this file. The
  # halo is recoloured AFTER the blur: the transparent border's pixels are
  # black underneath, and blurring alpha alone would make a dark smudge.
  theme = pkgs.runCommand "claudeos-plymouth" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    d=$out/share/plymouth/themes/claudeos
    mkdir -p $d
    magick ${../../assets/claude-logo.png} -fill '${c.withHashtag.base0D}' -colorize 100 $d/spark.png
    magick $d/spark.png -background none -bordercolor none -border 50% \
      -channel A -blur 0x28 -evaluate multiply 0.9 +channel \
      -fill '${c.withHashtag.base0D}' -colorize 100 $d/halo.png
    cp ${script} $d/claudeos.script
    cat > $d/claudeos.plymouth <<EOF
    [Plymouth Theme]
    Name=ClaudeOS
    ModuleName=script

    [script]
    ImageDir=$d
    ScriptFile=$d/claudeos.script
    EOF
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "claudeos";
    themePackages = [ theme ];
  };

  # Ours replaces Stylix's spinning-logo theme (it would set theme = "stylix").
  stylix.targets.plymouth.enable = false;
}
