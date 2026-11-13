pragma Singleton
// NeedsYou.qml — one ranked queue of the things that want the user right now,
// gathered from the singletons that already know about them. The island is its
// face (top item + count) and the island's popup lists the whole queue.
//
// Sources (all local state the bar already holds; this file polls nothing of
// its own and never calls a model):
//   · session → an interactive Claude session blocked on you: status
//               "waiting" in its ~/.claude/sessions/<pid>.json (Sessions.qml)
//   · health  → a failed claudeos-* / claude-* unit (Health.qml)
//   · pr      → an agent-authored PR awaiting review (Presence.waiting)
//   · card    → a live generated card (Cards.qml)
// Red CI is not here: nothing in the bar knows check status today, and a new
// poller for it would cost more than this queue is worth.
//
// Two ways in: a click on the island acts on the top item (Island.qml), and
// Super+N (the `needsnext` shortcut → next()) walks the queue from the
// keyboard — top item first, the one after it on a press within a few
// seconds, wrapping. An empty queue answers the key with a brief still
// "nothing waiting" face on the focused island (nothingWaiting).
//
// Items are plain data — {id, kind, tier, title, detail, since, ref} — and
// act(item) takes the user to one, through each source's own open path. No
// per-item closures: the builders run in loops, and a closure capturing a loop
// variable is the QV4 GC crash (.claude/rules/quickshell-qml.md).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // The ranked queue, most pressing first. Replaced only when its content
    // changes, so the sources' wholesale per-poll reassignments do not churn
    // the island's bindings or the popup's delegates.
    property var items: []
    readonly property int count: items.length
    readonly property var top: items.length > 0 ? items[0] : null

    // Tiers, in rank order. Kept as names so the island and the popup can
    // style by meaning rather than by number.
    readonly property int tierBlocking: 0 // a session waiting on your answer
    readonly property int tierFailure: 1  // something broke
    readonly property int tierReview: 2   // something to look over
    readonly property int tierInfo: 3     // informational

    // How an item looks, shared by the island face and the popup rows: a
    // glyph per kind, a colour per tier (blocking = accent, failure = warn,
    // the rest stay quiet in subtext).
    function glyph(item) {
        if (!item)
            return "";
        return item.kind === "session" ? Icons.question : item.kind === "health" ? Icons.bell : item.kind === "pr" ? Icons.ci : Icons.file;
    }
    function tint(item) {
        if (!item)
            return Theme.muted;
        return item.tier === root.tierBlocking ? Theme.accent : item.tier === root.tierFailure ? Theme.warn : Theme.subtext;
    }

    // "What needs me" (the summon action): the island on the focused monitor
    // opens its popup, which leads with this queue.
    signal summoned
    GlobalShortcut {
        appid: "quickshell"
        name: "needsyou"
        description: "Show what needs you"
        onPressed: root.summoned()
    }

    // "Go to what needs me" (Super+N, lib/keybindings.nix): the keyboard path
    // through the queue. Every press counts as a use (claudeos-usage, source
    // "key") — an empty-queue press is still you checking, so it is a use too.
    // Logged by the registry id only, never an item's title.
    signal nothingWaiting
    GlobalShortcut {
        appid: "quickshell"
        name: "needsnext"
        description: "Go to the next thing that needs you"
        onPressed: {
            Usage.log(Usage.idForGlobal("quickshell:needsnext"), "key");
            root.next();
        }
    }

    // The walk's cursor: the id of the item the key last went to, and when.
    // A press within nextWindowMs of the last one goes to the item after it in
    // the current ranking; a later press, or one whose remembered item has
    // left the queue, starts again from the top. The end wraps to the top, so
    // a one-item queue just goes to that item again.
    readonly property int nextWindowMs: 8000
    property string _cursorId: ""
    property real _cursorAt: 0
    function indexOfId(id) {
        for (let i = 0; i < root.items.length; i++)
            if (root.items[i].id === id)
                return i;
        return -1;
    }
    function next() {
        const list = root.items;
        const now = Date.now();
        if (list.length === 0) {
            root._cursorId = "";
            root.nothingWaiting();
            return;
        }
        let i = 0;
        if (root._cursorId !== "" && now - root._cursorAt < root.nextWindowMs) {
            const at = root.indexOfId(root._cursorId);
            if (at >= 0)
                i = (at + 1) % list.length;
        }
        root._cursorId = list[i].id;
        root._cursorAt = now;
        root.act(list[i]);
    }

    // ---- ranking: the one place the order is decided --------------------
    // Blocking on you first (a session stopped for a permission or a
    // question), then failures (a failed unit), then reviewable things (PRs),
    // then informational cards. Within a tier, oldest first: the thing that
    // has waited longest is the one you are furthest behind on. Ties (e.g.
    // everything first seen at bar start) fall back to the id, so the order is
    // stable from poll to poll.
    function compare(a, b) {
        if (a.tier !== b.tier)
            return a.tier - b.tier;
        if (a.since !== b.since)
            return a.since - b.since;
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    }

    // When each id was first seen, for sources that carry no timestamp of
    // their own (units, PRs, cards). id → ms epoch; pruned to the live set.
    property var _seen: ({})
    function seen(id, now, next) {
        const t = root._seen[id] ?? now;
        next[id] = t;
        return t;
    }

    function rebuild() {
        const now = Date.now();
        const next = {};
        const out = [];

        const waiting = Sessions.waiting;
        for (let i = 0; i < waiting.length; i++) {
            const s = waiting[i];
            out.push({
                id: "session-" + s.pid,
                kind: "session",
                tier: root.tierBlocking,
                title: s.name,
                detail: s.waitingFor !== "" ? s.waitingFor : "waiting for you",
                since: s.since,
                ref: s.pid
            });
        }

        const failed = Health.failedList;
        for (let i = 0; i < failed.length; i++) {
            const id = "unit-" + failed[i];
            out.push({
                id: id,
                kind: "health",
                tier: root.tierFailure,
                title: failed[i].replace(/\.service$/, ""),
                detail: "failed unit",
                since: root.seen(id, now, next),
                ref: failed[i]
            });
        }

        const prs = Presence.waiting;
        for (let i = 0; i < prs.length; i++) {
            const id = "pr-" + prs[i].number;
            out.push({
                id: id,
                kind: "pr",
                tier: root.tierReview,
                title: prs[i].title,
                detail: "#" + prs[i].number + " · " + prs[i].lane,
                // PR numbers are monotonic, so a lower number is the older PR
                // even when the bar first saw them all at once.
                since: root.seen(id, now, next) + prs[i].number / 1e6,
                ref: prs[i].number
            });
        }

        const cards = Cards.cards;
        for (let i = 0; i < cards.length; i++) {
            const id = "card-" + cards[i].id;
            out.push({
                id: id,
                kind: "card",
                tier: root.tierInfo,
                title: cards[i].title,
                detail: "card",
                since: root.seen(id, now, next),
                ref: cards[i].id
            });
        }

        root._seen = next;
        out.sort(root.compare);
        if (root.signature(out) !== root.signature(root.items))
            root.items = out;
    }
    function signature(list) {
        let s = "";
        for (let i = 0; i < list.length; i++)
            s += list[i].id + "\u0001" + list[i].title + "\u0001" + list[i].detail + "\u0002";
        return s;
    }

    Connections {
        target: Sessions
        function onLiveChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: Health
        function onFailedChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: Presence
        function onWaitingChanged() {
            root.rebuild();
        }
    }
    Connections {
        target: Cards
        function onCardsChanged() {
            root.rebuild();
        }
    }
    Component.onCompleted: root.rebuild()

    // ---- act: take the user to an item, via its source's own open path ----
    function act(item) {
        if (!item)
            return;
        if (item.kind === "session")
            root.focusSession(item.ref);
        else if (item.kind === "health")
            Health.openPopup();
        else if (item.kind === "pr")
            Presence.openPr(item.ref);
        else if (item.kind === "card")
            Cards.surfaceOpen = true;
    }

    // A session's window is the nearest ancestor of its `claude` process that
    // Hyprland knows as a client: the terminal for a CLI session, the Claude
    // desktop window for an app session. The probe prints that ancestor chain
    // ("P<pid>" per line) and the client list (one "C<json>" line); QML picks
    // the first ancestor with a window and focuses it, which also brings its
    // workspace forward.
    property var _chain: []
    property var _clients: []
    Process {
        id: finder
        stdout: SplitParser {
            onRead: line => {
                if (line.charAt(0) === "P")
                    root._chain.push(parseInt(line.slice(1)));
                else if (line.charAt(0) === "C") {
                    try {
                        root._clients = JSON.parse(line.slice(1));
                    } catch (e) {
                        root._clients = [];
                    }
                }
            }
        }
        onExited: root.focusFound()
    }
    function focusSession(pid) {
        if (finder.running)
            return;
        root._chain = [];
        root._clients = [];
        finder.command = ["sh", "-c", "p=\"$1\"; while [ -n \"$p\" ] && [ \"$p\" -gt 1 ] 2>/dev/null; do echo \"P$p\"; p=$(sed 's/.*) //' \"/proc/$p/stat\" 2>/dev/null | cut -d' ' -f2); done; printf 'C'; hyprctl clients -j 2>/dev/null | tr -d '\\n'; echo", "sh", "" + pid];
        finder.running = true;
    }
    function clientFor(pid) {
        for (let i = 0; i < root._clients.length; i++)
            if (root._clients[i].pid === pid)
                return root._clients[i];
        return null;
    }
    function focusFound() {
        for (let i = 0; i < root._chain.length; i++) {
            const c = root.clientFor(root._chain[i]);
            if (c && c.address) {
                const a = c.address.startsWith("0x") ? c.address : "0x" + c.address;
                Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + a + "\" })");
                return;
            }
        }
    }
}
