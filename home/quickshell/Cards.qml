// Cards.qml — the live model of generated surfaces (Phase 4). Cards are
// schema-validated DATA files under $XDG_RUNTIME_DIR/claudeos-cards.d/, one
// <id>.json per card, written by claudeos_card (lib/claude-script.nix).
//
// We POLL the dir (Process + Timer), exactly like Presence.qml polls agent.d —
// NOT FileView. The plan's first choice was a FileView watch, but Quickshell
// 0.3's FileView.watchChanges did not reliably pick up the writer's atomic
// rename (the new content lands on a fresh inode the file-watch never sees), so
// a card written to a running bar never appeared. Polling is the proven idiom
// here and cards change rarely, so a slow 3s cadence is negligible.
//
// Deterministic all the way: the writer already validated the JSON against the
// schema, so QML only parses + renders known-good data. Defensive anyway — any
// parse hiccup drops that one card, never breaks the bar.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{id, title, icon?, urgency?, sections}] — one per <id>.json in the dir.
    property var cards: []
    readonly property int count: cards.length

    // The surface is one overlay window (CardSurface.qml in shell.qml); the bar
    // glyph and the island (when cards exist) toggle it through this flag.
    property bool surfaceOpen: false
    function toggle() {
        surfaceOpen = !surfaceOpen;
    }

    // --- poll: one probe prints "I<id>" then the card's one-line json per file,
    // then a bare "END"; we accumulate and commit on END (so an empty dir clears
    // to []). jq isn't assumed on the shell PATH — the shell only cats, QML parses.
    property var _buf: []
    property string _pending: ""
    Process {
        id: probe
        command: ["sh", "-c", "d=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudeos-cards.d\"; for f in \"$d\"/*.json; do [ -e \"$f\" ] || continue; b=${f##*/}; b=${b%.json}; printf 'I%s\\n' \"$b\"; cat \"$f\"; echo; done; printf 'END\\n'"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root.cards = root._buf;
                    root._buf = [];
                    root._pending = "";
                    return;
                }
                if (line.charAt(0) === "I") {
                    root._pending = line.slice(1);
                    return;
                }
                try {
                    const o = JSON.parse(line);
                    if (o && o.title && o.sections)
                        root._buf.push(Object.assign({
                            id: root._pending
                        }, o));
                } catch (e)
                // a half-written file mid-install — skip; the next poll settles it.
                {}
                root._pending = "";
            }
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    // Dismiss one card by id: the claudeos-card CLI removes its file; the next
    // poll drops it (and the surface auto-closes when the last card is gone).
    Process {
        id: rm
    }
    function dismiss(id) {
        if (!id)
            return;
        rm.command = ["claudeos-card", "rm", "" + id];
        rm.running = true;
        // optimistic: drop it locally so the surface updates now, not next poll
        root.cards = root.cards.filter(c => c.id !== id);
    }
}
