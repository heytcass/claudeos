pragma Singleton
// Away.qml — "has nobody touched the seat for a while?"
//
// Ambient motion (the living wallpaper, the island's agent breath, steam off
// the caffeine mug) exists for someone looking at the screen. With nobody
// there it is pure heat: every endless animation keeps its window's render
// thread producing frames and Hyprland compositing them at full refresh rate,
// on every monitor. Measured 2026-11-25 on gti, docked: quickshell averaged
// ~42% of a core and Hyprland ~28% around the clock, fans on, desk empty.
//
// It ignores idle inhibitors on purpose (respectInhibitors: false). Caffeine
// holds an inhibitor for the whole of every agent run and every busy Claude
// session, which is exactly when the screen stays lit with nobody watching,
// so an inhibitor-respecting monitor would never call that idle. That
// inhibitor still does its own job (no lock, no blank, no suspend); this only
// decides whether scenery moves.
//
// Ambient animations add `&& !Away.away` to their `running`. Motion the user
// asked for (hover, press, popups, toasts) is never gated: it only happens
// while someone is present anyway. The first input flips `away` back and the
// scene picks up where it stopped.
import Quickshell
import Quickshell.Wayland // IdleMonitor (ext-idle-notify)

Singleton {
    id: root

    readonly property bool away: monitor.isIdle

    IdleMonitor {
        id: monitor
        enabled: true
        // Seconds. Short enough that a walk-away stops the heat within a couple
        // of minutes; long enough that reading without touching anything
        // doesn't freeze the scene under you.
        timeout: 120
        respectInhibitors: false
    }
}
