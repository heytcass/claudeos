// Notifications.qml — the shell IS the notification daemon now (replaces mako).
// Owns org.freedesktop.Notifications: `list` drives the live toasts (Toasts.qml)
// and `history` drives the notification center in the calendar dropdown.
// Only ONE NotificationServer may exist, so this is a Singleton and mako is off.
pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // active (tracked) notifications → toasts
    readonly property alias list: server.trackedNotifications
    // our own retained log → notification center
    readonly property alias history: historyModel

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
            // Without this the notification is freed the moment this returns.
            notif.tracked = true;

            // Retain a copy for the history center (independent of tracked).
            historyModel.insert(0, {
                summary: notif.summary,
                body: notif.body,
                appName: notif.appName,
                urgency: notif.urgency
            });
            while (historyModel.count > 100)
                historyModel.remove(historyModel.count - 1);
        }
    }
}
