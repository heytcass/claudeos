# home/hyprland.nix — Hyprland + a bespoke Quickshell bar, per-user config.
# Attached by modules/desktop/hyprland.nix (claude-os.hyprland.enable), the
# default desktop since the Phase 1 inversion; absent wherever GNOME is the
# desktop (gti until reinstall, transporter's `gnome` fallback entry). All
# colors come from the Stylix base16 palette (never hardcoded hex) — CLAUDE.md
# mandate.
#
# The bar is hand-authored QML under ./quickshell (the "build what I want, adopt
# no one's desktop" choice); it is themed by a Colors.qml singleton generated
# from the Stylix palette below. Companions (launcher/notifications/lock/idle/
# wallpaper) are small tools that Stylix auto-themes.
{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  # Plain (no-hash) base16 strings for Hyprland's rgba() color syntax.
  c = config.lib.stylix.colors;

  # gsd's sleep-inactive-battery policy, reimplemented for hypridle: suspend
  # only when NO AC adapter reports online (sysfs `online` exists only on AC
  # supplies, so a battery-only match set means suspend). On AC the machine
  # stays awake — overnight automation (auto-update, diary, morning desk)
  # depends on it, same intent as home/gnome.nix's dconf power settings.
  suspendOnBattery = pkgs.writeShellScript "suspend-on-battery" ''
    for ac in /sys/class/power_supply/*/online; do
      [ -e "$ac" ] || continue
      [ "$(cat "$ac")" = "1" ] && exit 0
    done
    systemctl suspend
  '';

  # Font names for the Quickshell Theme singleton — same source of truth the
  # rest of the system themes from (lib/theme.nix), so the bar matches.
  themeLib = import ../lib/theme.nix;

  # Card action registry (lib/card-actions.nix — same single source the card
  # writer validates against) → CardActions.qml, the closed name→argv map
  # CardRenderer.qml execDetaches. A card `run` can only ever name a key here.
  cardActions = import ../lib/card-actions.nix;
  cardActionCommands = builtins.toJSON (lib.mapAttrs (_n: v: v.command) cardActions);

  # --- Lua config helpers ---------------------------------------------------
  # The config is Lua (configType below). home-manager's generator renders each
  # `settings` attribute as `hl.<name>(...)`: an attrset becomes one call, a
  # LIST becomes one call per element, `_args` becomes a multi-argument call,
  # and mkLuaInline emits raw Lua. See lib.nix @ the pinned HM rev.
  inherit (lib.generators) mkLuaInline;

  # These were hyprlang `$mod` / `$terminal` / `$launcher` variables. They
  # CANNOT stay as settings keys: `"$mod" = …` would render `hl.$mod(…)` →
  # `<name> expected near '$'` (home-manager#9468, closed as not-planned since
  # it is a config-shape mismatch, not an HM bug). Plain Nix bindings are
  # simpler than Lua `_var` locals and Nix already interpolates them.
  mod = "SUPER";
  terminal = "ghostty";
  launcher = "fuzzel";

  # Always build command strings through toJSON — it produces a correct Lua
  # string literal and escapes the embedded quotes in the screenshot and rfkill
  # binds, which would otherwise terminate the literal early.
  mkExec = cmd: mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
  mkGlobal = name: mkLuaInline "hl.dsp.global(${builtins.toJSON name})";
  mkBind = keys: dsp: {
    _args = [
      keys
      dsp
    ];
  };
  mkBindOpts = keys: dsp: opts: {
    _args = [
      keys
      dsp
      opts
    ];
  };

  # Reuse THE keybinding source of truth — lib/keybindings.nix drives the GNOME
  # dconf binds AND the claudeos help screen, so converting it here keeps
  # Hyprland in sync by construction rather than duplicating the list.
  # Each entry's `binding` is a GTK accelerator like "<Super><Shift>a"; convert
  # to Hyprland's Lua `hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("…"))`.
  claudeBinds = import ../lib/keybindings.nix;
  modMap = {
    "Super" = "SUPER";
    "Shift" = "SHIFT";
    "Ctrl" = "CTRL";
    "Control" = "CTRL";
    "Alt" = "ALT";
  };
  bindTokens =
    b: lib.filter (s: s != "") (lib.splitString ">" (lib.replaceStrings [ "<" ] [ "" ] b.binding));
  toLuaBind =
    b:
    let
      tokens = bindTokens b;
      mods = map (m: modMap.${m} or (lib.toUpper m)) (lib.init tokens);
      key = lib.toUpper (lib.last tokens);
      # Lua joins modifiers and key with " + "; hyprlang used ", ".
      keys = lib.concatStringsSep " + " (mods ++ [ key ]);
      # An entry is either an exec bind (command) or a quickshell global.
      action = if b ? global then mkGlobal b.global else mkExec b.command;
    in
    mkBind keys action;

  # The cheat sheet's Claude section, as data — CheatSheet.qml reads this from
  # the generated Keybinds.qml singleton, so Super+H can never drift from the
  # real binds again. JSON is a valid QML literal; toJSON does the escaping.
  cheatEntries = builtins.toJSON (
    map (b: {
      keys = lib.init (bindTokens b) ++ [ (lib.toUpper (lib.last (bindTokens b))) ];
      desc = b.short or b.help;
    }) claudeBinds
  );

  # One shared 4px rhythm: Hyprland's outer window gaps (general.gaps_out) and
  # the bar islands' screen-edge margins + float gap (Theme.edgeGap) all read
  # this, so the pills stay aligned with tiled window edges by construction.
  # Tightened 2026-07-12 for the 12.5" 1080p@1.5× panel.
  edgeGap = 4;

  # Assemble the Quickshell config dir: the static QML from ./quickshell plus a
  # Colors.qml singleton generated from the live Stylix palette. A directory
  # `.source` symlink can't have a file added inside it, so build the dir in a
  # derivation instead.
  # The Theme.qml text, from the shared generator. Also consumed by
  # modules/desktop/greeter.nix so the login screen and the bar cannot drift.
  themeQml = import ../lib/quickshell-theme.nix {
    colors = c;
    inherit themeLib edgeGap;
  };

  qsConfig = pkgs.runCommand "claudeos-quickshell" { inherit themeQml; } ''
    mkdir -p "$out"
    cp -r ${./quickshell}/. "$out/"
    # Theme.qml is generated by lib/quickshell-theme.nix, NOT inline here —
    # the greeter (modules/desktop/greeter.nix) runs as the `greeter` system
    # user and needs the same singleton, so one generator feeds both. Passed
    # via an env var rather than heredoc-interpolated: the text contains `$`
    # and QML braces that a shell heredoc would be free to chew on.
    printf '%s' "$themeQml" > "$out/Theme.qml"

    # Keybinds.qml — the Claude keybindings as data, generated from
    # lib/keybindings.nix (same source that drives the Hyprland binds and the
    # claudeos help screen). CheatSheet.qml reads Keybinds.claude, so the
    # Super+H cheat sheet stays in sync by construction. Edit the .nix, never
    # this file.
    cat > "$out/Keybinds.qml" <<'EOF'
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
      readonly property var claude: ${cheatEntries}
    }
    EOF

    # CardActions.qml — the closed name→argv registry for card `run` actions,
    # generated from lib/card-actions.nix (the same source the card writer
    # validates against). CardRenderer.qml looks up commands[name]; a card can
    # never introduce a command that isn't declared here. Edit the .nix.
    cat > "$out/CardActions.qml" <<'EOF'
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
      // Parens: a var binding that starts with `{` is otherwise parsed as a JS
      // block, not an object literal (same reason Routes.qml wraps its map).
      readonly property var commands: (${cardActionCommands})
    }
    EOF

    # cava config for the island's audio spectrum (Spectrum.qml runs
    # `cava -p cava.conf`). Raw ascii on stdout: `bars` values 0..1000 per line,
    # ';'-separated, one frame per newline. bars here MUST match Spectrum.bars.
    cat > "$out/cava.conf" <<'EOF'
    [general]
    mode = normal
    bars = 14
    framerate = 60
    autosens = 1

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    channels = mono
    mono_option = average
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 1000
    bar_delimiter = 59
    frame_delimiter = 10
    EOF
  '';
in
{
  # Portals: the HM hyprland module auto-enables xdg.portal with ONLY the
  # hyprland backend, and HM's NIX_XDG_DESKTOP_PORTAL_DIR (hm-session-vars)
  # SHADOWS the system portal dir — so the frontend saw no gtk backend, and
  # FileChooser/Settings had no implementation (Claude Desktop SIGABRTed opening
  # a directory picker, 2026-07-11). Complete the per-user set instead: gtk
  # rides alongside xdph, and the config routes anything hyprland doesn't
  # implement (FileChooser, Settings, …) to gtk — mirroring the system module.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # The bar owns network and bluetooth status (NetworkWidget/BluetoothWidget),
  # so the stock tray applets would double them up. Their packages stay —
  # nm-connection-editor and blueman-manager are the settings surfaces — but
  # the XDG autostart entries are shadowed Hidden: the user dir wins over
  # /run/current-system/sw/etc/xdg/autostart for the same basename, and the
  # systemd xdg-autostart generator skips Hidden entries.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    # Lua, not hyprlang. Hyprland 0.56.1 began warning on screen that .conf
    # support is removed in 0.57 (commit ca90dfb0), and the legacy config code
    # is ALREADY deleted from upstream main (PR #15539, -3696 lines) — so this
    # is a deadline, not a preference. `settings` below is Lua-shaped
    # accordingly; the two shapes are mutually exclusive, which is why the port
    # and the flip land in one commit.
    #
    # home-manager's own default flips to "lua" at stateVersion >= 26.05; ours
    # is 24.11, so it stays explicit here.
    configType = "lua";
    # UWSM owns the session (system module sets programs.hyprland.withUWSM);
    # don't also let home-manager start a hyprland systemd target.
    systemd.enable = false;

    # All of the below is Lua-shaped, NOT hyprlang. See the helper preamble in
    # the `let` block above for how each shape renders. Validate any change with
    #   Hyprland --verify-config -c <generated hyprland.lua>
    # (CLAUDE.md, "Compositor config isn't validated by the build") — and note
    # `hyprctl keyword` no longer works at all under Lua; it is gated on
    # CONFIG_LEGACY, while `hyprctl eval` is gated on CONFIG_LUA.
    settings = {
      # Display scale + dock layout. Left unset, Hyprland auto-picks a
      # fractional scale from DPI (1.5 on these 1920x1080 panels); both hosts
      # want native 1:1 (100%) on the built-in panel instead.
      #
      # gti's desk dock (dialed in live 2026-07-17): Dell | laptop |
      # Dell-portrait. Externals were briefly at 0.8 to shrink their UI toward
      # the 13" panel's density, but scale < 1.0 breaks Chromium/Electron apps
      # (Claude Desktop, VS Code): they clamp their surface to the physical
      # resolution and paint only 80% of a tile — so externals run native 1.0
      # (2026-07-18). The Dells are keyed by desc/serial — DP-* port numbers
      # shuffle between dock plug-ins, serials don't. Physical alignment: left
      # Dell's bottom sits at the laptop's vertical midpoint on the desk; the
      # laptop's logical offset is then biased 150px down so the density
      # mismatch (92 px/in on the Dell vs 165 on the 13" panel) splits its
      # crossing error across the shared edge instead of piling up at the top.
      # The portrait Dell is offset so top-of-laptop cursor crossings land level
      # (same mismatch story: only one crossing height can be physically true —
      # we picked where Tom crosses).
      # Undocked, eDP-1's fixed offset is harmless (sole monitor, origin moot).
      #
      # Lua shape: a LIST renders one `hl.monitor{…}` call per element. The old
      # comma-string's positional fields become named ones, the trailing
      # `transform, 3` keyword pair becomes a plain `transform` field, and the
      # catch-all's empty output stays expressible as `output = ""`.
      monitor =
        if osConfig.networking.hostName == "gti" then
          [
            {
              output = "eDP-1";
              mode = "1920x1080@60";
              position = "1920x1470";
              scale = 1;
            }
            {
              output = "desc:Dell Inc. DELL P2419H FXP0RB3";
              mode = "1920x1080@60";
              position = "0x780";
              scale = 1.0;
            }
            {
              output = "desc:Dell Inc. DELL P2419H 9HYLVF3";
              mode = "1920x1080@60";
              position = "3840x253";
              scale = 1.0;
              transform = 3;
            }
            # Anything else (projectors, other docks): sane default, no 1.5 auto.
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 1;
            }
          ]
        else
          [
            {
              output = "eDP-1";
              mode = "preferred";
              position = "auto";
              scale = 1;
            }
          ];

      # Everything that was a plain hyprlang option block (general/decoration/
      # dwindle/input/misc) lives under one `config` attr, which renders as a
      # single `hl.config{…}`. Stylix writes here too (its Lua branch emits
      # `settings.config = colorSettings`) — the two attrsets merge into that
      # one call, and the key sets are disjoint at every leaf, so there is no
      # collision and no override needed.
      config = {
        # Keyboard: Hyprland owns the in-session Wayland layout (it does NOT
        # inherit GNOME's dconf input-sources), so mirror the Colemak setup
        # here. The console keymap lives in modules/common/locale.nix.
        input = {
          kb_layout = "us";
          kb_variant = "colemak";
          # gsd parity (home/gnome.nix dconf): 250ms delay, 25ms interval —
          # Hyprland expresses the interval as a rate, 1000/25 = 40 repeats/s.
          repeat_delay = 250;
          repeat_rate = 40;
          # Touchpad. The tap setting is fleet-wide, but the click METHOD is
          # not: the two hosts are physically different pointing devices, so
          # anything about buttons has to be host-conditional. See below.
          touchpad = {
            # Tap-to-click OFF fleet-wide (2026-08-09, was true). Every click
            # is now a real physical press. Taps fire on contact, so resting a
            # thumb or brushing the pad mid-sentence lands a click wherever
            # the cursor happens to be — the cost of that is silent and
            # occasionally destructive, whereas the cost of pressing is a gram
            # of force.
            # KNOCK-ON: this also retires two-finger *tap* as right-click, so
            # right-click is now exclusively a physical press on both hosts —
            # via clickfinger on gti, via the real button on transporter.
            #
            # NOTE THE RENAME: hyprlang spelled this `tap-to-click`. Under Lua
            # the canonical key is `tap_to_click`; the hyphenated form is a
            # hard error (`unknown config key`), which is the good outcome —
            # it fails loudly rather than silently ignoring the setting.
            tap_to_click = false;
          }
          # gti (XPS 13 9370) is a buttonless clickpad: the entire surface is
          # one button, so right-click has to be synthesised. libinput's
          # default is "button areas", where the press only counts as
          # right-click in the bottom-right *corner* — press with two fingers
          # anywhere else and you silently get a left click, which reads as
          # "right click is broken". clickfinger counts fingers instead:
          # 1 = left, 2 = right, 3 = middle, anywhere on the surface.
          # Trade-off: it RETIRES the bottom-right corner press, which becomes
          # a plain left click.
          #
          # transporter (Latitude 7280) is deliberately excluded — it has
          # discrete physical buttons below the pad, so right-click is already
          # a real button and needs no synthesising. libinput only offers the
          # clickfinger method on clickpads in the first place, so setting it
          # there would be a no-op that misleads the next reader into thinking
          # the fleet is uniform. It isn't.
          // lib.optionalAttrs (osConfig.networking.hostName == "gti") {
            clickfinger_behavior = true;
          };
        };

        general = {
          border_size = 2;
          # Tightened 2026-07-12 (was 4/8): on the 12.5" 1080p@1.5× panel the
          # airy gaps read as dead space and windows felt cramped.
          gaps_in = 2;
          gaps_out = edgeGap; # shared with the bar's Theme.edgeGap (see above)
          # Border colors come from Stylix's Hyprland target (base0D terracotta
          # on the active border, from the same palette) — setting them here
          # conflicts with Stylix's own definitions.
        };

        decoration.rounding = 6; # matched to the tighter gaps (was 8)

        # dwindle (default layout): keep the split direction when a window
        # closes so the layout doesn't reflow unexpectedly.
        dwindle.preserve_split = true;

        # Recovery hatch for a dead lockscreen. Default is false, which is how
        # gti got stranded at a TTY on 2026-08-15: home-manager activation
        # stopped hypridle.service, whose cgroup teardown SIGTERM'd the hyprlock
        # holding the active lock, and the relock was then REFUSED with
        # "onLockFinished called. Seems we got yeeten. Is another lockscreen
        # running?" — this option is exactly what that refusal is gated on.
        # With it on, the TTY recovery is `hyprctl dispatch exec hyprlock`,
        # which re-arms a working prompt while KEEPING the session locked —
        # safer on a laptop than clear_crashed_lockscreen(), which unlocks
        # outright. See docs/known-issues.md 2026-08-15.
        #
        # Note this migration also revives the OTHER escape hatch: under Lua,
        # `hyprctl eval 'hl.clear_crashed_lockscreen()'` — the command the
        # crashed-lockscreen screen tells you to run — finally works.
        misc.allow_session_lock_restore = true;
      };

      # Touchpad gestures (2026-08-08). Directions are axes or sides, and an
      # axis SHADOWS its sides at the same finger count — `3, horizontal` makes
      # a later `3, left` unreachable, which the binary reports as "Gesture will
      # be overshadowed by a previous gesture". So keep one granularity per
      # finger count per axis. Valid actions: workspace, move, resize, special,
      # fullscreen, close, dispatcher.
      #
      # Lua shape: one `hl.gesture{…}` per element. Note the old form's trailing
      # positional arg (`special, magic`) becomes the NAMED field
      # `workspace_name` — there is no positional slot for it.
      gesture = [
        # Three fingers sideways = the workspaces 1-5 already on $mod+<n>.
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
        # Three fingers up = fullscreen, mirroring $mod+F. Safe next to the
        # horizontal bind above: different axis, so no overshadowing.
        {
          fingers = 3;
          direction = "up";
          action = "fullscreen";
        }
        # Four fingers up = the "magic" scratchpad ($mod+S / $mod+SHIFT+S, in
        # `bind` below). Deliberately a different finger count from the
        # workspace swipe — the scratchpad is not part of the 1-5 rotation and
        # shouldn't feel like it is.
        {
          fingers = 4;
          direction = "up";
          action = "special";
          workspace_name = "magic";
        }
      ];

      # Cursor: point Xcursor at the Stylix Adwaita theme (cursor.package + size
      # from modules/desktop/theme.nix) so the built-in Hyprland cursor doesn't
      # show. Also applied live via `hyprctl setcursor` in the start hook.
      #
      # Lua shape: `hl.env` takes TWO arguments, so each entry needs `_args`.
      # A single-argument call is a hard error ("second argument (value) must be
      # a string"), so the old "KEY,VALUE" single string cannot be reused.
      env = [
        {
          _args = [
            "XCURSOR_THEME"
            "Adwaita"
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            "20"
          ];
        }
      ];

      # NB: hyprpaper, hypridle, and gammastep are deliberately NOT here — they
      # run as home-manager systemd units bound to graphical-session.target,
      # which UWSM activates. That makes the session-entry choice at regreet
      # LOAD-BEARING: the plain "Hyprland" entry never activates the target,
      # stranding all three (no wallpaper, no idle-lock, no night light —
      # observed first post-inversion login 2026-07-12). Always pick
      # "Hyprland (UWSM)"; regreet remembers the last choice per user in
      # /var/lib/regreet/state.toml.
      #
      # This was `exec-once`, which has NO direct Lua keyword — it becomes an
      # event subscription. Putting these at top level instead would be a real
      # bug on two counts: they would re-run on every `hyprctl reload`, AND
      # `Hyprland --verify-config` EXECUTES top-level code, so merely validating
      # the config would spawn a second bar. Verified empirically: a top-level
      # `hl.exec_cmd` runs during verification; the same call inside this hook
      # does not. No collision with home-manager's own start hook — HM only
      # emits one when `systemd.enable = true`, and that is false here.
      on = {
        _args = [
          "hyprland.start"
          (mkLuaInline (
            "function()\n"
            + lib.concatMapStrings (cmd: "  hl.exec_cmd(${builtins.toJSON cmd})\n") [
              "qs" # the bespoke Quickshell bar
              # Apply the Adwaita cursor at runtime (belt-and-suspenders with env).
              "hyprctl setcursor Adwaita 20"
              # Start + unlock the Secret Service (org.freedesktop.secrets) so
              # Claude and other libsecret apps can save logins. A bare WM
              # session must start the daemon's components itself.
              #
              # NOTE `ssh` is deliberately absent: gnome-keyring 50 accepts only
              # `pkcs11,secrets` (`gnome-keyring-daemon --help`), and the ssh
              # agent moved out to gcr-ssh-agent — a separately socket-activated
              # service that already serves SSH_AUTH_SOCK
              # (/run/user/1000/gcr/ssh) and holds the git signing key. Passing
              # `ssh` here was a silent no-op, not a working setting.
              "gnome-keyring-daemon --start --components=secrets,pkcs11"
              # NO polkit agent launched here any more. The bar IS the agent
              # (home/quickshell/PolkitDialog.qml), which is what let the
              # XDG_SESSION_ID ordering workaround be deleted outright — see
              # modules/desktop/hyprland.nix.
            ]
            + "end"
          ))
        ];
      };

      # Auto-float utility windows + the GTK file picker, so dialogs don't tile
      # awkwardly. Match by app class; add more as they come up.
      #
      # Lua shape: `match:<prop> <regex>` becomes a nested `match` table and the
      # effects become sibling fields — `float on` is the BOOLEAN `float = true`,
      # not the string "on". Effect names are unchanged (`dim_around`, not
      # `dimaround`). `name` is optional but makes a rule addressable at runtime.
      #
      # Regex escaping: this is a Nix indented string, which does NOT process
      # backslashes, so `\.` here is a literal backslash-dot — exactly what the
      # regex engine needs. Getting it wrong is SILENT (a rule that matches
      # nothing), the same class of bug as the 2026-07-11 comma-grammar one.
      window_rule = [
        {
          name = "float-utils";
          match.class = "^(pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator)$";
          float = true;
        }
        {
          name = "float-portal";
          match.class = "^(xdg-desktop-portal-gtk)$";
          float = true;
        }
        # Morning desk (Chrome --app on ~/Desk/today/index.html) presents like
        # the SUPER+H cheat sheet: floating card, everything behind it dimmed.
        # The class derives from the fixed file path; Super+Q dismisses (a real
        # window can't do the overlay's click-away). Size is a % of the monitor
        # so it fits every host (a fixed 900px ran off a 720px-logical laptop);
        # claudeos-desk-open (morning-desk.nix) reads the mapped size back and
        # nudges the window to true center post-map — the rule's own position
        # effects lose a race with Chrome's first configure, and `center` is
        # fooled by Chrome's CSD shadow geometry.
        {
          name = "morning-desk";
          match.class = ''^(chrome-.*Desk_today_index\.html-Default)$'';
          float = true;
          size = "85% 90%";
          dim_around = true;
        }
      ];

      # ALL FIVE hyprlang bind keywords collapse into this one list under Lua;
      # the old flag suffix becomes an options table:
      #   bind   → (no opts)      bindm → { mouse = true; }
      #   binde  → { repeating; } bindl → { locked; }   bindel → both
      #
      # ⚠️ Bind option NAMES are the one thing `--verify-config` does not check:
      # a typo'd option returns `config ok` and is silently dropped. The valid
      # set (per the binary's own hl.meta.lua stub) is: repeating, locked,
      # release, non_consuming, transparent, ignore_mods, dont_inhibit,
      # long_press, submap_universal, click, drag, description, desc, device,
      # allow_input_capture, mouse. Check these by eye, not by validator.
      bind = [
        # Drag to move (SUPER+left), drag to resize (SUPER+right) — the
        # biggest everyday win a bare compositor otherwise lacks.
        (mkBindOpts "${mod} + mouse:272" (mkLuaInline "hl.dsp.window.drag()") { mouse = true; })
        (mkBindOpts "${mod} + mouse:273" (mkLuaInline "hl.dsp.window.resize()") { mouse = true; })

        (mkBind "${mod} + Return" (mkExec terminal))
        (mkBind "${mod} + Q" (mkLuaInline "hl.dsp.window.close()"))
        (mkBind "${mod} + Space" (mkExec launcher))
        (mkBind "${mod} + L" (mkExec "hyprlock"))
        (mkBind "${mod} + V" (mkLuaInline ''hl.dsp.window.float({ action = "toggle" })''))
        (mkBind "${mod} + F" (mkLuaInline "hl.dsp.window.fullscreen()"))
        # toggle pseudo-tiling for the focused window
        (mkBind "${mod} + P" (mkLuaInline "hl.dsp.window.pseudo()"))
        # floating keybind cheat sheet
        (mkBind "${mod} + H" (mkGlobal "quickshell:cheatsheet"))
        # idle-inhibit hold (Caffeine.qml)
        (mkBind "${mod} + I" (mkGlobal "quickshell:caffeine"))
        # Super+W (wish overlay) rides lib/keybindings.nix as a `global`
        # entry, alongside the exec binds — one source of truth for all.

        # Focus with arrows — layout-independent (no vim h/j/k/l: the physical
        # keys don't land on the home row under Colemak, so they're not muscle
        # memory here). Direction words: the binary accepts both "left" and
        # "l" (parseDirectionStr), but full words match the shipped example
        # and a typo in them IS caught by the verifier.
        (mkBind "${mod} + left" (mkLuaInline ''hl.dsp.focus({ direction = "left" })''))
        (mkBind "${mod} + right" (mkLuaInline ''hl.dsp.focus({ direction = "right" })''))
        (mkBind "${mod} + up" (mkLuaInline ''hl.dsp.focus({ direction = "up" })''))
        (mkBind "${mod} + down" (mkLuaInline ''hl.dsp.focus({ direction = "down" })''))

        # Move the focused window within the layout.
        (mkBind "${mod} + SHIFT + left" (mkLuaInline ''hl.dsp.window.move({ direction = "left" })''))
        (mkBind "${mod} + SHIFT + right" (mkLuaInline ''hl.dsp.window.move({ direction = "right" })''))
        (mkBind "${mod} + SHIFT + up" (mkLuaInline ''hl.dsp.window.move({ direction = "up" })''))
        (mkBind "${mod} + SHIFT + down" (mkLuaInline ''hl.dsp.window.move({ direction = "down" })''))

        # Resize the focused window (40px steps).
        (mkBind "${mod} + CTRL + left" (
          mkLuaInline "hl.dsp.window.resize({ x = -40, y = 0, relative = true })"
        ))
        (mkBind "${mod} + CTRL + right" (
          mkLuaInline "hl.dsp.window.resize({ x = 40, y = 0, relative = true })"
        ))
        (mkBind "${mod} + CTRL + up" (
          mkLuaInline "hl.dsp.window.resize({ x = 0, y = -40, relative = true })"
        ))
        (mkBind "${mod} + CTRL + down" (
          mkLuaInline "hl.dsp.window.resize({ x = 0, y = 40, relative = true })"
        ))

        # Scratchpad: SUPER+S toggles a hidden "magic" workspace,
        # SUPER+SHIFT+S stashes the focused window into it.
        (mkBind "${mod} + S" (mkLuaInline ''hl.dsp.workspace.toggle_special("magic")''))
        (mkBind "${mod} + SHIFT + S" (mkLuaInline ''hl.dsp.window.move({ workspace = "special:magic" })''))

        # Graceful session exit. (The wiki warns UWSM sessions off the `exit`
        # dispatcher — it removes Hyprland from under its clients and
        # interferes with ordered shutdown — and this session IS UWSM-managed.
        # Behaviour is carried over unchanged here to keep this migration
        # behaviour-preserving; switching to `uwsm stop` is a separate call.)
        (mkBind "${mod} + SHIFT + M" (mkLuaInline "hl.dsp.exit()"))

        # Plain screenshot — grim only, no Claude hand-off (contrast with
        # Super+Shift+A / Super+Ctrl+A in lib/keybindings.nix, which analyze
        # the capture). Whole screen straight to a file; no region picker.
        # The leading bare comma of the hyprlang form (",Print") is simply
        # absent under Lua — an unmodified key stands alone.
        (mkBind "Print" (
          mkExec "grim \"$HOME/Pictures/Screenshot_$(date +%Y%m%d-%H%M%S).png\" && notify-send 'Screenshot saved' \"$HOME/Pictures\""
        ))

        # Media + brightness keys — GNOME's settings-daemon handled these; a
        # bare compositor doesn't. repeating = fire while held; locked = fire
        # even with the session locked.
        (mkBindOpts "XF86AudioRaiseVolume" (mkExec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") {
          locked = true;
          repeating = true;
        })
        (mkBindOpts "XF86AudioLowerVolume" (mkExec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") {
          locked = true;
          repeating = true;
        })
        (mkBindOpts "XF86MonBrightnessUp" (mkExec "brightnessctl set 5%+") {
          locked = true;
          repeating = true;
        })
        (mkBindOpts "XF86MonBrightnessDown" (mkExec "brightnessctl set 5%-") {
          locked = true;
          repeating = true;
        })

        (mkBindOpts "XF86AudioMute" (mkExec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
          locked = true;
        })
        (mkBindOpts "XF86AudioPlay" (mkExec "playerctl play-pause") { locked = true; })
        (mkBindOpts "XF86AudioNext" (mkExec "playerctl next") { locked = true; })
        (mkBindOpts "XF86AudioPrev" (mkExec "playerctl previous") { locked = true; })

        # Fn+Home (airplane mode) reports only — it does NOT toggle. The
        # kernel already does that itself: CONFIG_RFKILL_INPUT binds an rfkill
        # handler straight to "Dell WMI hotkeys" and "Intel HID events" (see
        # /proc/bus/input/devices), so KEY_RFKILL blocks every radio in kernel
        # space with nothing in userspace involved. Toggling here too would
        # double-fire and cancel itself out.
        #
        # What was missing is feedback, and that is the whole bug: on
        # 2026-08-07 this key silently killed wifi + bluetooth mid-undock and
        # nothing said so — GNOME's airplane OSD left with the rip-out and the
        # bar widget hid itself when disconnected. Read the state back after a
        # beat (the kernel flips it on keypress, so an immediate read races).
        (mkBindOpts "XF86RFKill"
          (mkExec "sleep 0.3 && (rfkill list wlan | grep -q 'Soft blocked: yes' && notify-send -u low 'Airplane mode on' 'Radios blocked — Fn+Home again to restore' || notify-send -u low 'Radios on' 'Wifi and Bluetooth unblocked')")
          { locked = true; }
        )
      ]
      ++ (lib.concatMap (n: [
        (mkBind "${mod} + ${toString n}" (mkLuaInline "hl.dsp.focus({ workspace = ${toString n} })"))
        (mkBind "${mod} + SHIFT + ${toString n}" (
          mkLuaInline "hl.dsp.window.move({ workspace = ${toString n} })"
        ))
      ]) (lib.range 1 5))
      ++ (map toLuaBind claudeBinds);
    };
  };

  # Force-overwrite hyprland.conf. If HM ever fails to place this (e.g. an
  # unrelated activation error) Hyprland boots configless and writes its own
  # STUB config as a *real* file at this path. On the next activation HM's
  # backupFileExtension="backup" dance then dies with "backup would be clobbered"
  # (the stub's own .backup already exists) — aborting the ENTIRE activation, so
  # NO home files deploy and the session comes up with default binds and no bar.
  # force=true makes HM overwrite the stub outright, breaking that trap. (Cost:
  # a hand-edited hyprland.conf would be silently replaced — acceptable, this
  # file is fully declarative.)
  # NOTE THE FILENAME: this MUST track configType. Under "lua" home-manager
  # puts hyprlangConfigFile behind `mkIf false`, so nothing defines source/text
  # for hyprland.conf — and HM's file type declares `source` with no default,
  # leaving a force-only definition used-but-not-defined, which fails
  # EVALUATION outright.
  xdg.configFile."hypr/hyprland.lua".force = true;

  # The bespoke bar: Quickshell package + the generated config dir. cava feeds
  # the island's audio spectrum (Spectrum.qml runs it on the default sink).
  # qml-preview is the fast-reload dev helper (see .claude/skills/qml-dial-in).
  home.packages = [
    pkgs.quickshell
    pkgs.cava
    # notify-send — the shell owns the daemon, but scripts (and bar testing)
    # still need the client.
    pkgs.libnotify
    (pkgs.writeShellScriptBin "qml-preview" (builtins.readFile ./qml-preview.sh))
  ];
  xdg.configFile."quickshell".source = qsConfig;

  # Light companions — Stylix auto-themes those with targets (autoEnable is on).
  programs.fuzzel.enable = true;
  # Notifications are owned by the Quickshell shell now (home/quickshell —
  # Notifications.qml runs the org.freedesktop.Notifications server + toasts).
  # mako is deliberately NOT enabled: only one process can own that D-Bus name,
  # so running mako would silently steal notifications from the shell.
  programs.hyprlock.enable = true;

  # Idle → lock, matching GNOME's 5-min lock (home/gnome.nix idle-delay 300).
  # hypridle does nothing without listeners, so define them: lock at 5 min,
  # screen off at 10, suspend at 20 IF on battery (AC stays awake for
  # overnight automation — the suspendOnBattery script re-implements gsd's
  # sleep-inactive-battery policy), and lock before sleep.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # hyprlock gets its OWN transient unit, never hypridle's cgroup. A
        # bare `hyprlock` here is spawned inside hypridle.service, and systemd
        # attributes by cgroup, not parentage — so every home-manager
        # activation that stops hypridle SIGTERM'd the live lock with it
        # (KillMode=control-group), which is exactly the 2026-08-15 lockscreen
        # wedge (docs/known-issues.md). hypridle also carries Restart=always,
        # so it bounces on far more than switches. With its own scope the lock
        # survives any hypridle stop/restart/crash; --collect reaps the unit
        # on exit so the name is reusable, and the fixed unit name doubles as
        # an idempotency guard alongside pidof (systemd-run refuses a
        # duplicate unit). Same launch pattern, same verified env inheritance,
        # as the transient-unit probes of 2026-08-16.
        lock_cmd = "pidof hyprlock || systemd-run --user --collect --unit=hyprlock-active hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1200;
          on-timeout = "${suspendOnBattery}";
        }
      ];
    };
  };

  # Night light — gsd's dies with GNOME. Same automatic sun schedule via
  # geoclue (system side wires the service + gammastep's authorization in
  # modules/desktop/hyprland.nix). Temperatures match GNOME night-light's
  # defaults: no filtering by day, 2700K at night.
  services.gammastep = {
    enable = true;
    provider = "geoclue2";
    temperature = {
      day = 6500;
      night = 2700;
    };
  };
  # Wallpaper: enable hyprpaper; Stylix's hyprpaper target sets the image from
  # stylix.image, so setting settings here would conflict with it.
  services.hyprpaper.enable = true;
}
