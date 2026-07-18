// Notifications.qml — the shell IS the notification daemon now (replaces mako).
// Owns org.freedesktop.Notifications: `list` drives the live toasts (Toasts.qml)
// and `history` drives the notification center in the calendar dropdown.
// Only ONE NotificationServer may exist, so this is a Singleton and mako is off.
pragma Singleton
import QtQuick // ListModel
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // active (tracked) notifications → toasts
    readonly property alias list: server.trackedNotifications
    // our own retained log → notification center
    readonly property alias history: historyModel

    // Fired on every new notification — the center island listens to this to
    // peek the notification inline (Island.qml).
    signal posted(string summary, string body, string appName, int urgency)

    ListModel {
        id: historyModel
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
            // Each notification renders in EXACTLY ONE live surface (plus the
            // history center, always). Actionable ones — action buttons or
            // Critical urgency — own the corner toast, kept alive via `tracked`.
            // Everything else is ambient: it peeks-and-vanishes on the island
            // via `posted`. The two are mutually exclusive, so nothing renders
            // twice (WO-0 of the notification-routing plan; the full router
            // that fans `posted` into more destinations lands in Phase 1b).
            const actionable = notif.actions.length > 0 || notif.urgency === NotificationUrgency.Critical;
            notif.tracked = actionable;

            // Retain a copy for the history center (independent of tracked).
            historyModel.insert(0, {
                summary: notif.summary,
                body: notif.body,
                appName: notif.appName,
                urgency: notif.urgency
            });
            while (historyModel.count > 100)
                historyModel.remove(historyModel.count - 1);

            // Ambient only: an actionable notification already owns the corner,
            // so it must not also peek the island.
            if (!actionable)
                root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
        }
    }
}
