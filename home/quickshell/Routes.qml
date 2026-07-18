// Routes.qml — notification routing policy, as data (Phase 1b).
//
// The router lives in Notifications.qml; this singleton holds only the per-APP
// OVERRIDES that trump the default urgency/actions logic. Changing where an
// app's notifications land is a one-line edit here — never a change to router
// logic — which is the whole point: routing policy is ring-1 reviewable config,
// not behaviour buried in QML.
//
// Destinations:
//   "toast"  — corner toast (Toasts.qml); needs a decision now
//   "peek"   — island peek (Island.qml); ambient/FYI, glance and gone
//   "quiet"  — held, flushed as one summary at a boundary (leave fullscreen /
//              return from idle); FYI that shouldn't interrupt
//   "ledger" — no live surface; the work product's home is the PresencePanel
//
// Empty by default: the defaults (Critical/actionable → toast, low → quiet,
// else → peek) live in Notifications.route(). Add an entry to override a
// specific app — e.g. "Slack": "quiet", "Spotify": "peek".
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
