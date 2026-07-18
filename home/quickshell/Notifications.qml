// Notifications.qml — the shell IS the notification daemon (replaces mako), and
// since Phase 1b it is also the ROUTER + ARBITER. It owns
// org.freedesktop.Notifications, so every notification flows through
// onNotification, and the router resolves each to EXACTLY ONE live surface
// (plus the history centre, always):
//   · toast  — needs a decision now (Toasts.qml renders `tracked` server notifs)
//   · peek   — ambient/FYI, glance and gone (Island.qml listens to `posted`)
//   · quiet  — FYI that shouldn't interrupt: held, then flushed as ONE summary
//              peek at a boundary — leaving fullscreen, or returning from idle
//   · ledger — lane work product; its home is the PresencePanel, no live surface
// Routing is deterministic: explicit x-claudeos-dest hint → per-app override
// table (Routes.qml) → urgency/actions default. Arbitration then adjusts
// per-destination TIMING: while a window is fullscreen, non-Critical toasts
// divert to the quiet queue (Critical punches through). Model output never
// reaches here — it enters the bar only as the notification's own text.
//
// Verified live against Quickshell 0.3.0 (2026-07-18): `notify-send -u low`
// surfaces as NotificationUrgency.Low (0), and client hints surface as plain JS
// strings on `notif.hints` — so both quiet-routing inputs work directly, no
// urgency workaround or String()-unwrapping needed. The return-from-idle
// boundary uses Quickshell's own IdleMonitor (ext-idle-notify) rather than a
// hypridle on-resume script poking a FileView-watched sentinel: in-process, no
// filesystem watch, no Nix wiring — and the sentinel path was the piece that
// never fired in the first arbitration attempt.
pragma Singleton
import QtQuick // ListModel
import Quickshell
import Quickshell.Hyprland // fullscreen boundary (rawEvent)
import Quickshell.Wayland // IdleMonitor — return-from-idle boundary
import Quickshell.Services.Notifications

Singleton {
    id: root

    // active (tracked) notifications → toasts
    readonly property alias list: server.trackedNotifications
    // our own retained log → notification center
    readonly property alias history: historyModel
    // held FYIs awaiting a boundary flush; expose the count for any badge
    readonly property int quietCount: quietModel.count

    // Fired for a peek — the center island listens and peeks it inline (Island.qml).
    signal posted(string summary, string body, string appName, int urgency)

    ListModel {
        id: historyModel
    }
    ListModel {
        id: quietModel
    }

    // ── Fullscreen boundary ────────────────────────────────────────────────
    // While the focused window is fullscreen, a would-be toast (non-Critical)
    // defers to the quiet queue rather than punching over the video/game.
    // Hyprland emits `fullscreen>>1/0`; same rawEvent channel Workspaces.qml reads.
    property bool fullscreenActive: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen")
                root.fullscreenActive = event.data.trim() === "1";
        }
    }
    // Leaving fullscreen is a task boundary — surface what waited.
    onFullscreenActiveChanged: if (!fullscreenActive)
        root.flushQuiet();

    // ── Return-from-idle boundary ──────────────────────────────────────────
    // Coming back after being idle is the other boundary. Quickshell's native
    // IdleMonitor gives it in-process: isIdle flips true after `timeout` of no
    // seat input and false on the next input; the resume (→false) edge flushes.
    // respectInhibitors, so a playing video (which holds an idle inhibitor)
    // isn't counted as idle. `timeout` is in seconds; 300 aligns with the
    // session lock (home/hyprland.nix hypridle listener).
    IdleMonitor {
        enabled: true
        timeout: 300
        respectInhibitors: true
        onIsIdleChanged: if (!isIdle)
            root.flushQuiet()
    }

    // Resolve a notification to one destination: "toast" | "peek" | "quiet" |
    // "ledger". Priority: explicit per-notif hint → per-app override table →
    // urgency/actions default. Hint/override values are whitelisted so a typo
    // can't route a notification into a dead destination and silently drop it.
    function route(notif) {
        const valid = d => d === "toast" || d === "peek" || d === "quiet" || d === "ledger";
        const hinted = notif.hints ? notif.hints["x-claudeos-dest"] : undefined;
        if (valid(hinted))
            return hinted;
        const appOverride = Routes.appRoutes[notif.appName];
        if (valid(appOverride))
            return appOverride;
        if (notif.urgency === NotificationUrgency.Critical || notif.actions.length > 0)
            return "toast";
        if (notif.urgency === NotificationUrgency.Low)
            return "quiet";
        return "peek";
    }

    // Boundary flush: nothing held → no-op; one held FYI re-peeks as itself;
    // several collapse into a single summary peek (tap opens the centre).
    function flushQuiet() {
        const n = quietModel.count;
        if (n === 0)
            return;
        if (n === 1) {
            const it = quietModel.get(0);
            root.posted(it.summary, it.body, it.appName, it.urgency);
        } else {
            root.posted(n + " notifications while you were away", "tap to open the centre", "ClaudeOS", NotificationUrgency.Normal);
        }
        console.log("[notif-router] flushed", n, "quiet notification(s)");
        quietModel.clear();
    }

    // The centre (CalendarPopup) opening IS the user looking at notifications —
    // the held ones are already in history, so drop them without a summary peek.
    function markQuietSeen() {
        if (quietModel.count > 0) {
            console.log("[notif-router] centre opened; cleared", quietModel.count, "quiet");
            quietModel.clear();
        }
    }

    NotificationServer {
        id: server

        // Capability flags default to false — opt in to what the UI renders.
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: false

        onNotification: notif => {
            // History always retains a copy, independent of routing.
            historyModel.insert(0, {
                summary: notif.summary,
                body: notif.body,
                appName: notif.appName,
                urgency: notif.urgency
            });
            while (historyModel.count > 100)
                historyModel.remove(historyModel.count - 1);

            let dest = root.route(notif);
            // Defer, don't drop: a would-be toast waits in the quiet queue while
            // a window is fullscreen — except Critical, which always punches
            // through immediately.
            if (dest === "toast" && root.fullscreenActive && notif.urgency !== NotificationUrgency.Critical)
                dest = "quiet";

            switch (dest) {
            case "toast":
                notif.tracked = true; // Toasts.qml renders tracked notifs
                break;
            case "quiet":
                quietModel.append({
                    summary: notif.summary,
                    body: notif.body,
                    appName: notif.appName,
                    urgency: notif.urgency
                });
                console.log("[notif-router] held (quiet):", notif.summary, "— queue now", quietModel.count);
                break;
            case "ledger":
                break; // lane work product; the PresencePanel is its home
            case "peek":
            default:
                root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
                break;
            }
        }
    }
}
