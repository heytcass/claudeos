//@ pragma UseQApplication
// UseQApplication (Qt Widgets) is REQUIRED for Quickshell.Services.SystemTray;
// without it the tray silently fails to appear.

import QtQuick
import Quickshell

// Root of the ClaudeOS shell: one Bar per monitor, the notification toast
// stack, and (touched below so it binds the D-Bus name at startup) the
// notification server. Colors/fonts come from the Stylix-generated Theme
// singleton (Theme.qml, written by home/hyprland.nix).
ShellRoot {
    // Force the Notifications singleton to instantiate at startup so the
    // NotificationServer claims org.freedesktop.Notifications immediately,
    // rather than lazily when a popup first reads it (which would drop any
    // notifications fired before then). Touch Presence too so its polls start
    // now rather than when the panel is first opened. Sonic listens for agent
    // and OSD edges, so it must exist before the first one. Jasper announces
    // fresh insights itself, and nothing on screen reads it until the calendar
    // popup does, so it is touched here too.
    Component.onCompleted: {
        Notifications.list;
        Presence.live;
        Cards.count;
        Contexts.contexts;
        Shelf.count;
        Sonic.dir;
        Jasper.text;
    }

    // The living wallpaper, one per monitor on the background layer.
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    // One bar per monitor.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Notification toasts (their own layer-shell windows, per monitor).
    Toasts {}

    // SUPER+H keybinding cheat sheet (its own overlay window).
    CheatSheet {}

    // SUPER+Tab / four-finger swipe up: live workspace overview (own overlay).
    Overview {}

    // SUPER+O / right-click in the Overview: a pinned live corner mini-window.
    Pin {}

    // Print: freeze the screen, pick a region, copy / save / read / ask Claude.
    RegionShot {
        id: regionTool
    }
    Spotlight {} // "Claude points": `claudeos-spotlight` dims all but a target

    // The wish prompt — a sentence in, a wish/* PR out (its own overlay).
    // Opened from the summon's Wish row.
    WishOverlay {
        id: wishOverlay
    }

    // Polkit authentication agent. Not keybound — it surfaces itself whenever
    // something asks for authorization. Lives in the bar's process on purpose:
    // that is what removes soteria's XDG_SESSION_ID ordering workaround, since
    // by the time the bar exists the session variables are already exported.
    PolkitDialog {}

    // SUPER+Space summon — apps and every Claude action in one ranked list,
    // plus the deterministic routes ($command / question? / save as / resume /
    // task), each visible before Enter. It drives the wish prompt and the
    // region tool directly, so it is handed both.
    Summon {
        wish: wishOverlay
        regionShot: regionTool
    }

    // The PR inbox — agent-authored PRs waiting for review. Opened from the
    // proposals glyph via Presence.panelOpen; its own overlay window.
    ReviewPanel {}

    // Generated surfaces (cards) — the long tail of single-use UI, rendered
    // deterministically from schema-validated data. Opened from the CardsWidget
    // bar glyph / the island via Cards.surfaceOpen; its own overlay window.
    CardSurface {}
}
