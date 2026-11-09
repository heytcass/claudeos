pragma Singleton
// Sessions.qml — the interactive Claude Code sessions on this machine, read
// from the signal the app already publishes: ~/.claude/sessions/<pid>.json
// (mode 644, one per running `claude`), whose `name` is the sidebar title and
// whose `status` flips busy/idle as turns start and end. This replaced the
// per-prompt marker hooks and the haiku "activity phrase" summarizer
// (2026-11-08): the app's own title is stable, costs nothing, and several
// sessions no longer fight over one phrase by mtime.
//
// Only `*.json` is read. The `<pid>.key` files beside them hold a peer token
// (mode 600) and are never opened. A file whose pid is gone (a crashed
// session leaves its file behind) is skipped via /proc.
//
// Headless lanes are a different thing — they still pulse through Agent.qml /
// Presence.qml with a curated phrase and own the island's agent face. These
// sessions only get a spark-and-count on the clock face, a listing in the
// calendar popup, and — when one has been busy long enough to be the thing
// you are waiting on — a promotion to the face with its title.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{pid, name, status, since, cwd}] — live interactive sessions, newest
    // first. `since` is statusUpdatedAt (ms epoch): how long it has been in
    // its current status.
    property var live: []
    readonly property int busy: live.filter(s => s.status === "busy").length
    // Sorted ids of the busy sessions; Sonic diffs this (with Agent.agents)
    // so each turn's start and finish is audible even while others work.
    property var busyIds: []

    // Title of the session promoted to the island face: busy for longer than
    // `promoteAfter`, longest-running first. Stable while it stays busy — a
    // title does not churn like a marker's mtime did. "" when none qualifies.
    readonly property int promoteAfter: 90000
    property string promoted: ""

    // One probe per poll: "S<json>" per live session, then "END". The shell
    // only filters and concatenates; QML parses, as in Presence.qml.
    property var _buf: []
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "d=\"$HOME/.claude/sessions\"; [ -d \"$d\" ] || { echo END; exit 0; }; for f in \"$d\"/*.json; do [ -f \"$f\" ] || continue; p=${f##*/}; p=${p%.json}; [ -d \"/proc/$p\" ] || continue; printf 'S'; tr -d '\\n' < \"$f\"; echo; done; echo END"
        ]
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root.commit(root._buf);
                    root._buf = [];
                    return;
                }
                if (line.charAt(0) !== "S")
                    return;
                try {
                    const j = JSON.parse(line.slice(1));
                    if (j.kind !== "interactive")
                        return;
                    root._buf.push({
                        pid: j.pid,
                        name: (j.name ?? "").trim() || "Claude Code",
                        status: j.status ?? "idle",
                        since: j.statusUpdatedAt ?? j.updatedAt ?? 0,
                        cwd: j.cwd ?? ""
                    });
                } catch (e) {
                // half-written file mid-update — next poll gets the settled one
                }
            }
        }
    }

    function commit(list) {
        list.sort((a, b) => (b.since ?? 0) - (a.since ?? 0));
        root.live = list;
        const ids = list.filter(s => s.status === "busy").map(s => "session-" + s.pid).sort();
        if (ids.join("\n") !== root.busyIds.join("\n"))
            root.busyIds = ids;
        const now = Date.now();
        const long = list.filter(s => s.status === "busy" && now - s.since > root.promoteAfter).sort((a, b) => a.since - b.since);
        const next = long.length > 0 ? long[0].name : "";
        if (next !== root.promoted)
            root.promoted = next;
    }

    // How long a session has been in its status, for the popup's status line.
    function ago(since) {
        const s = Math.max(0, Math.round((Date.now() - since) / 1000));
        if (s < 60)
            return "just now";
        const m = Math.round(s / 60);
        if (m < 60)
            return m + " min";
        const h = Math.floor(m / 60);
        return h + " h " + (m % 60) + " min";
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
