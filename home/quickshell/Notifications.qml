// Notifications.qml — the shell IS the notification daemon (replaces mako), and
// since Phase 1b it is also the ROUTER. It owns org.freedesktop.Notifications,
// so every notification flows through onNotification, and the router resolves
// each to EXACTLY ONE live surface (plus the history centre, always):
//   · toast  — needs a decision now (Toasts.qml renders `tracked` server notifs)
//   · peek   — ambient/FYI, glance and gone (Island.qml listens to `posted`)
// Routing is deterministic: action buttons or Critical urgency → toast, else
// peek, with a per-app override table (Routes.qml) and an optional
// x-claudeos-dest hint. Model output never reaches here — it enters the bar
// only as the notification's own text, rendered by handwritten components.
//
// NB: the arbitration layer from the 1b plan — a quiet queue with fullscreen
// defer and idle/unlock flush — is intentionally NOT here. It half-worked on
// this Quickshell 0.3.0 stack (the server collapses low urgency to normal, and
// the flush surfacing couldn't be verified), so it's being built and proven
// separately rather than shipped shaky. This core is the verified, safe part.
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

    // Fired for a peek — the center island listens and peeks it inline (Island.qml).
    signal posted(string summary, string body, string appName, int urgency)

    ListModel {
        id: historyModel
    }

    // Resolve a notification to one destination: "toast" or "peek". Priority:
    // explicit per-notif hint → per-app override table → actions/urgency default.
    // (Overrides are honoured only for the surfaces this core renders; the
    // quiet/ledger destinations arrive with the arbitration follow-up.)
    function route(notif) {
        const hinted = notif.hints ? notif.hints["x-claudeos-dest"] : undefined;
        const appOverride = Routes.appRoutes[notif.appName];
        const override = (hinted === "toast" || hinted === "peek") ? hinted : (appOverride === "toast" || appOverride === "peek") ? appOverride : "";
        if (override)
            return override;
        if (notif.actions.length > 0 || notif.urgency === NotificationUrgency.Critical)
            return "toast";
        return "peek";
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

            // Exactly one live surface. Actionable ones own the corner toast
            // (kept alive via `tracked`); everything else peeks the island once.
            if (root.route(notif) === "toast")
                notif.tracked = true;
            else
                root.posted(notif.summary, notif.body, notif.appName, notif.urgency);
        }
    }
}
