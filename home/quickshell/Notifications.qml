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
            // The center island peeks EVERY notification (Island.qml listens to
            // `posted`), so the corner toast is reserved for ones you might need
            // to act on or that must persist: those with action buttons or
            // Critical urgency. Simple notifications peek-and-vanish on the island
            // only. `tracked` controls whether a toast is kept alive at all.
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

            root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
        }
    }
}
