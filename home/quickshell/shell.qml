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
    // notifications fired before then).
    Component.onCompleted: Notifications.list

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
}
