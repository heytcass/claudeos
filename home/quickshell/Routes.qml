// Routes.qml — notification routing policy, as data (Phase 1b).
//
// The router lives in Notifications.qml; this singleton holds only the per-APP
// OVERRIDES that trump the default urgency/actions logic. Changing where an
// app's notifications land is a one-line edit here — never a change to router
// logic — which is the whole point: routing policy is ring-1 reviewable config,
// not behaviour buried in QML.
//
// Destinations (this core): "toast" (corner toast; needs a decision now) or
// "peek" (island peek; ambient/FYI, glance and gone). The "quiet" and "ledger"
// destinations from the plan arrive with the arbitration follow-up.
//
// Empty by default: the defaults (actionable/Critical → toast, else → peek)
// live in Notifications.route(). Add an entry to override a specific app —
// e.g. "Spotify": "peek", "SomeChattyApp": "toast".
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // Keyed by the notification's appName (the `--app-name` a client sends).
    readonly property var appRoutes: ({
            // "Slack": "quiet",
            // "Spotify": "peek",
        })
}
