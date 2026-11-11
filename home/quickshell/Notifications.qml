pragma Singleton
// Notifications.qml — the shell IS the notification daemon (replaces mako), and
// since Phase 1b it is also the ROUTER + ARBITER. It owns
// org.freedesktop.Notifications, so every notification flows through
// onNotification, and the router resolves each to EXACTLY ONE live surface
// (plus the history centre, always):
//   · toast  — needs a decision now (Toasts.qml renders `tracked` server notifs)
//   · peek   — ambient/FYI, glance and gone: now a short-lived toast too. It
//              used to peek inside the center island, which since 2026-11
//              speaks only for the time and for Claude; the route name stays
//              so Routes.qml overrides keep meaning "an FYI, not a decision".
//   · quiet  — FYI that shouldn't interrupt: held, then flushed as ONE summary
//              note at a boundary — leaving fullscreen, or returning from idle
//   · ledger — lane work product; history centre only, no live surface
// Routing is deterministic: explicit x-claudeos-dest hint → per-app override
// table (Routes.qml) → urgency/actions default. Arbitration then adjusts
// per-destination TIMING: while a window is fullscreen, non-Critical toasts
// and peeks divert to the quiet queue (Critical punches through). Model output
// never reaches here — it enters the bar only as the notification's own text.
//
// Not everything the bar wants to say is a D-Bus notification: the quiet
// flush and Jasper's fresh insight are the bar's own words. Those go through
// announce() into `notes`, which Toasts.qml renders in the same stack.
//
// Verified live against Quickshell 0.3.0 (2026-07-18): `notify-send -u low`
// surfaces as NotificationUrgency.Low (0), and client hints surface as plain JS
// strings on `notif.hints` — so both quiet-routing inputs work directly, no
// urgency workaround or String()-unwrapping needed. The return-from-idle
// boundary uses Quickshell's own IdleMonitor (ext-idle-notify) rather than a
// hypridle on-resume script poking a FileView-watched sentinel: in-process, no
// filesystem watch, no Nix wiring — and the sentinel path was the piece that
// never fired in the first arbitration attempt.
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

    // The bar's own short notes ({uid, summary, body, urgency, at}) → toasts.
    readonly property alias notes: noteModel

    ListModel {
        id: historyModel
    }
    ListModel {
        id: quietModel
    }
    ListModel {
        id: noteModel
    }

    // ── Notes: the bar speaking for itself ─────────────────────────────────
    // A card in the toast stack with no app behind it — no icon, no actions,
    // not in history (what it summarises already is). Expiry lives here, not
    // in Toasts.qml: every monitor renders the same model, and one owner
    // means one removal rather than a race between per-screen timers.
    property int _noteSeq: 0
    readonly property int noteLife: 6000
    // Low urgency is glance-and-gone: a Low toast (Toasts.qml, which also
    // honours a shorter sender timeout) or Low note leaves after this.
    readonly property int lowLife: 3000
    function announce(summary, body, urgency) {
        root._noteSeq += 1;
        noteModel.append({
            uid: root._noteSeq,
            summary: summary,
            body: body ?? "",
            urgency: urgency ?? NotificationUrgency.Normal,
            at: Date.now()
        });
    }
    function dismissNote(uid) {
        for (let i = 0; i < noteModel.count; i++)
            if (noteModel.get(i).uid === uid) {
                noteModel.remove(i);
                return;
            }
    }
    Timer {
        interval: 500
        repeat: true
        running: noteModel.count > 0
        onTriggered: {
            const now = Date.now();
            for (let i = noteModel.count - 1; i >= 0; i--) {
                const it = noteModel.get(i);
                const life = it.urgency === NotificationUrgency.Low ? root.lowLife : root.noteLife;
                if (it.at <= now - life)
                    noteModel.remove(i);
            }
        }
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

    // Boundary flush: nothing held → no-op; one held FYI is announced as
    // itself; several collapse into a single summary note pointing at the
    // centre (which opens from the clock).
    function flushQuiet() {
        const n = quietModel.count;
        if (n === 0)
            return;
        if (n === 1) {
            const it = quietModel.get(0);
            root.announce(it.summary, it.body, it.urgency);
        } else {
            root.announce(n + " notifications while you were away", "click the clock to read them", NotificationUrgency.Normal);
        }
        console.log("[notif-router] flushed", n, "quiet notification(s)");
        quietModel.clear();
    }

    // The centre (CalendarPopup) opening IS the user looking at notifications —
    // the held ones are already in history, so drop them without a summary note.
    function markQuietSeen() {
        if (quietModel.count > 0) {
            console.log("[notif-router] centre opened; cleared", quietModel.count, "quiet");
            quietModel.clear();
        }
    }

    // ── Metadata sanitising ────────────────────────────────────────────────
    // Agent clients (the Claude desktop app) quote a turn's opening text, which
    // for an automated turn is a machine wrapper like <ci-monitor-event>…. The
    // tell is the hyphen: the markup a notification body may carry (b, i, u, a,
    // img) never has one, so hyphenated tags are stripped for every app without
    // needing to know the sender's appName. Known tags become a glyph; a null
    // entry drops the element with its contents (never meant for the user).
    readonly property var metaTags: ({
            "ci-monitor-event": Icons.ci,
            "side-sessions-event": Icons.sessions,
            "task-notification": Icons.tasks,
            "system-reminder": null
        })
    function clean(text) {
        if (!text || text.indexOf("-") < 0)
            return text;
        // Clients may escape the brackets; unescape only hyphenated tags.
        let s = text.replace(/&lt;(\/?[a-z]+(?:-[a-z]+)+[^&]*?)&gt;/gi, "<$1>");
        if (!/<\/?[a-z]+(?:-[a-z]+)+/i.test(s))
            return text;
        for (const tag in root.metaTags) {
            const glyph = root.metaTags[tag];
            if (glyph === null) // a truncated body may lack the close tag: drop to the end
                s = s.replace(new RegExp("<" + tag + "\\b[^>]*>[\\s\\S]*?(?:</" + tag + ">|$)", "gi"), " ");
            else
                s = s.replace(new RegExp("<" + tag + "\\b[^>]*>", "gi"), glyph + " ");
        }
        // Anything else hyphenated: drop the tag, keep its text. A tag cut off
        // by the client's truncation (no closing >) goes too.
        s = s.replace(/<\/?[a-z]+(?:-[a-z]+)+[^>]*(?:>|$)/gi, " ");
        return s.replace(/\s+/g, " ").trim();
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
            const summary = root.clean(notif.summary);
            const body = root.clean(notif.body);
            // History always retains a copy, independent of routing.
            historyModel.insert(0, {
                summary: summary,
                body: body,
                appName: notif.appName,
                urgency: notif.urgency
            });
            while (historyModel.count > 100)
                historyModel.remove(historyModel.count - 1);

            let dest = root.route(notif);
            // Defer, don't drop: a would-be toast (a peek is one now) waits in
            // the quiet queue while a window is fullscreen — except Critical,
            // which always punches through immediately.
            if ((dest === "toast" || dest === "peek") && root.fullscreenActive && notif.urgency !== NotificationUrgency.Critical)
                dest = "quiet";

            switch (dest) {
            case "quiet":
                quietModel.append({
                    summary: summary,
                    body: body,
                    appName: notif.appName,
                    urgency: notif.urgency
                });
                console.log("[notif-router] held (quiet):", summary, "— queue now", quietModel.count);
                break;
            case "ledger":
                break; // lane work product; history centre only
            case "toast":
            case "peek": // a short-lived toast since the island stopped peeking
            default:
                notif.tracked = true; // Toasts.qml renders tracked notifs
                Sonic.notify(notif.urgency);
                break;
            }
        }
    }
}
