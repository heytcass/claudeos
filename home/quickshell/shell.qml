//@ pragma UseQApplication
// UseQApplication (Qt Widgets) is REQUIRED for Quickshell.Services.SystemTray;
// without it the tray silently fails to appear.

import QtQuick
import Quickshell

// Entry point for the bespoke ClaudeOS bar. Colors come from the Stylix-
// generated Colors.qml singleton (dropped into this dir by home/hyprland.nix)
// and are auto-registered, so Bar.qml references `Colors.*` directly.
ShellRoot {
    // One bar per monitor. Variants injects `modelData` (the QuickshellScreen)
    // into each Bar; Bar is a PanelWindow that anchors itself to the top edge.
    Variants {
        model: Quickshell.screens
        Bar {}
    }
}
