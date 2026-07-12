// Caffeine.qml — idle-inhibit state, replacing GNOME's caffeine extension.
// Two holds compose (decided 2026-07-11, "keybind + auto on agent activity"):
//   manual — SUPER+I (Hyprland: `bind = $mod, I, global, quickshell:caffeine`)
//   auto   — while Agent.qml reports activity, so long agent runs are never
//            locked or suspended mid-flight.
// The actual Wayland inhibitor lives in Bar.qml (the protocol needs a window
// surface, which a singleton doesn't have); the bar shows a mug only while
// a hold is active — no permanent widget.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // Deliberate user hold — independent of the agent's, so it survives an
    // agent run ending, and vice versa.
    property bool manual: false

    readonly property bool inhibited: manual || Agent.active

    GlobalShortcut {
        appid: "quickshell"
        name: "caffeine"
        description: "Toggle idle/lock inhibit (caffeine)"
        onPressed: root.manual = !root.manual
    }
}
