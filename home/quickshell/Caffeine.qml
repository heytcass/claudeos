pragma Singleton
// Caffeine.qml — idle-inhibit state, replacing GNOME's caffeine extension.
// Two holds compose (decided 2026-07-11, "keybind + auto on agent activity"):
//   manual — SUPER+I (Hyprland: `bind = $mod, I, global, quickshell:caffeine`)
//   auto   — while Agent.qml reports a lane or Sessions.qml a busy Claude
//            session, so long agent runs are never locked or suspended
//            mid-flight.
// The bar shows a mug only while one of those holds is active (no permanent
// widget).
//
// HOW the hold reaches hypridle: a logind idle lock (`systemd-inhibit
// --what=idle`), not a Wayland inhibitor. hypridle runs with
// ignore_wayland_inhibit (home/hyprland.nix) because the Claude desktop app
// holds a Wayland idle inhibitor on its window for as long as Remote Control
// is connected, which is always: its log showed one keep-awake claim from
// 2026-11-21 20:24 onward, never released, and hyprctl reported
// com.anthropic.Claude inhibitingIdle=true for 69 minutes with zero busy
// sessions (2026-11-25). The app means "don't suspend", but on Hyprland that
// inhibitor also stops the lock and the screen-off, so the laptop sat
// unlocked, screens on, for days. A Hyprland `idle_inhibit = "none"` rule
// cannot override a client's own inhibitor (tested live on 0.57.2), so the
// filter has to sit on hypridle's side.
//
// Ignoring every Wayland inhibitor would also drop mpv's (it has no other
// channel on Wayland), so this file BRIDGES them: it polls which windows
// Hyprland reports as inhibiting idle, drops the ignored classes, and holds
// the same logind lock for the rest. Chrome's video and screen-share holds
// arrive over D-Bus, which hypridle still honors directly.
//
// The lock is `systemd-inhibit … cat` with stdin on a pipe from the bar: if
// the bar dies, the pipe closes, cat exits and the lock goes with it. A
// crashed bar fails toward LOCKING, never toward a screen that stays open.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    // Deliberate user hold — independent of the agent's, so it survives an
    // agent run ending, and vice versa.
    property bool manual: false

    // Busy interactive Claude sessions count too (Sessions.qml) — a long turn
    // should not end in a locked screen either.
    readonly property bool inhibited: manual || Agent.active || Sessions.busy > 0

    // Window classes whose Wayland idle inhibitor is NOT passed on. Claude's
    // own while-working hold is redundant here: Sessions.busy covers it.
    readonly property var ignoredClasses: ["com.anthropic.Claude"]

    // Classes of the other windows Hyprland reports as inhibiting idle
    // (mpv playing, a fullscreen idle_inhibit rule, …).
    property var appHolders: []

    readonly property bool holding: inhibited || appHolders.length > 0

    Process {
        id: lock
        running: root.holding
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=idle", "--who=ClaudeOS bar", "--why=Caffeine or an app is keeping the screen awake", "--mode=block", "cat"]
    }

    Process {
        id: probe
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let held = [];
                try {
                    held = JSON.parse(text).filter(c => c.inhibitingIdle && !root.ignoredClasses.includes(c.class)).map(c => c.class).sort();
                } catch (e) {
                    return; // half-read or hyprctl hiccup; next poll settles it
                }
                if (held.join("\n") !== root.appHolders.join("\n"))
                    root.appHolders = held;
            }
        }
    }

    // hypridle's shortest timeout is 300 s, so a 10 s poll is ample.
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "caffeine"
        description: "Toggle idle/lock inhibit (caffeine)"
        onPressed: root.manual = !root.manual
    }
}
