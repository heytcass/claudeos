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
// calendar popup, a promotion to the agent face with their title once one
// has been busy long enough to be the thing you are waiting on, and — when a
// real turn ends — the island's brief "done" face (`finished`).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{pid, name, status, since, cwd, waitingFor}] — live interactive
    // sessions, newest first. `since` is statusUpdatedAt (ms epoch): how long
    // it has been in its current status. status is busy / idle / waiting.
    property var live: []
    readonly property int busy: live.filter(s => s.status === "busy").length
    // Sessions blocked on you: status "waiting" (a permission dialog or a
    // question). The island's NeedsYou queue puts these first.
    readonly property var waiting: live.filter(s => s.status === "waiting")
    // Sorted ids of the busy sessions; Sonic diffs this (with Agent.agents)
    // so each turn's start and finish is audible even while others work.
    property var busyIds: []

    // Title of the session promoted to the island face: busy for longer than
    // `promoteAfter`, longest-running first. Stable while it stays busy — a
    // title does not churn like a marker's mtime did. "" when none qualifies.
    readonly property int promoteAfter: 90000
    property string promoted: ""

    // A turn that was worth waiting on just ended: fired from commit() for a
    // session busy at the previous poll that is now idle or gone, after at
    // least `finishAfter` of work (a quick reply is not news). The island
    // shows it as its "done" face.
    signal finished(string name)
    readonly property int finishAfter: 20000
    // pid → {since, name} for the sessions busy at the previous poll; `since`
    // is when that busy stretch began. Empty until the first poll commits, so
    // the first poll after a bar start can never fire `finished`.
    property var _busyStart: ({})

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
                        cwd: j.cwd ?? "",
                        // Set with status "waiting": what the session is
                        // blocked on (a permission dialog, "input needed", …).
                        waitingFor: typeof j.waitingFor === "string" ? j.waitingFor : ""
                    });
                } catch (e) {
                // half-written file mid-update — next poll gets the settled one
                }
            }
        }
    }

    // Title of the listed session with this pid (a string key), or undefined.
    function nameOf(list, pid) {
        for (let i = 0; i < list.length; i++)
            if (String(list[i].pid) === pid)
                return list[i].name;
        return undefined;
    }

    function commit(list) {
        list.sort((a, b) => (b.since ?? 0) - (a.since ?? 0));
        root.live = list;
        const ids = list.filter(s => s.status === "busy").map(s => "session-" + s.pid).sort();        if (ids.join("\n") !== root.busyIds.join("\n"))
            root.busyIds = ids;
        const now = Date.now();
        const prev = root._busyStart;
        const nowBusy = {};
        for (const s of list)
            // A permission prompt or question mid-turn ("waiting") is not the
            // end of that turn: carry its busy stretch on, so `finished` fires
            // when the turn really ends, not when it stops to ask you.
            if (s.status === "busy" || (s.status === "waiting" && prev[s.pid] !== undefined))
                nowBusy[s.pid] = {
                    since: prev[s.pid]?.since ?? s.since,
                    name: s.name
                };
        root._busyStart = nowBusy;
        for (const pid in prev) {
            if (nowBusy[pid] !== undefined || now - prev[pid].since < root.finishAfter)
                continue;
            // Still listed (now idle) → its current title; gone → the last one seen.
            // No closure in this loop body: an arrow function capturing the
            // loop's own `pid` makes QV4 allocate a block context on every
            // iteration, and a GC triggered by that allocation segfaults
            // marking the JS stack (Qt 6.12; two bar crashes on 2026-11-11,
            // reproduced in isolation). nameOf() does the same lookup.
            root.finished(root.nameOf(list, pid) ?? prev[pid].name);
        }
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
