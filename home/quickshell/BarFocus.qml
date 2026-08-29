pragma Singleton
// BarFocus.qml — "is the window this item lives in on the focused monitor?"
//
// Bar.qml is a per-screen variant, so every monitor gets its own PanelWindow —
// and Qt gives every window its own QSGRenderThread. Any always-on animation
// therefore burns one render thread PER MONITOR to say exactly the same thing
// several times over. Ambient motion (the island's agent breath, steam off the
// caffeine mug) should ask this singleton and hold still off-focus. Motion the
// user asked for directly — a hover, a press, a transient toast — should NOT be
// gated: it belongs to the monitor it happens on.
//
// Reactive by construction: isFocused() reads `focusedName` on every call, and
// that property is backed by Hyprland.focusedMonitor's notify signal, so any
// binding calling it re-evaluates when focus moves. Hyprland.monitorFor() is a
// plain method — invisible to the binding engine, so a binding built on it
// would latch at startup and never update. Hence compare-by-name.
//
// Fails OPEN: unknown focus or unknown screen animates. A regression here costs
// what the bar already cost, never a silently frozen widget.
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // "" while Hyprland hasn't reported a focused monitor yet.
    readonly property string focusedName: Hyprland.focusedMonitor?.name ?? ""

    // `win` is the caller's `QsWindow.window`.
    function isFocused(win) {
        const f = root.focusedName;
        const n = win?.screen?.name ?? "";
        return f === "" || n === "" || f === n;
    }
}
