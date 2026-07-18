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
    // now rather than when the panel is first opened.
    Component.onCompleted: {
        Notifications.list;
        Presence.live;
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

    // SUPER+W wish prompt — a sentence in, a wish/* PR out (its own overlay).
    WishOverlay {}

    // SUPER+R intent line — one input that routes itself (app / $command /
    // question? / wish), deterministically, with the route shown before commit.
    IntentLine {}

    // The second-operator surface — working / waiting / recently finished.
    // Opened from the island (agent mode) or the proposals glyph via
    // Presence.panelOpen; its own overlay window.
    PresencePanel {}
}
