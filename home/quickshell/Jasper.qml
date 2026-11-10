pragma Singleton
// Jasper.qml — the personal-companion insight, read from the lane's cache file.
// modules/apps/jasper.nix writes jasper-insight.txt on the monitor-cache
// contract; this polls it cheaply, exactly like Agent.qml polls for activity.
// `text` is the one-sentence insight (empty when the lane has said nothing —
// the calendar popup's Jasper row then hides itself); `stale` goes true once
// it's older than 6h, so the bar can dim a companion that's gone quiet rather
// than lie that it's fresh.
//
// Jasper has no place on the island any more (2026-11): the sentence lives at
// the top of the calendar popup, and a FRESH insight is announced once as a
// toast note. That announcement lives here because this singleton exists
// exactly once — a per-monitor Bar would announce it once per screen.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string text: ""
    property bool stale: false

    // What the first poll after a bar start reads is not news — only a change
    // after that settles is (the poll is every 20 s, so a 30 s grace covers
    // the first read). Notifications never reads Jasper, so no load cycle.
    property bool settled: false
    Timer {
        interval: 30000
        running: true
        onTriggered: root.settled = true
    }
    onTextChanged: {
        // Split here rather than read emoji/sentence: inside this handler
        // those bindings may not have re-evaluated for the new text yet.
        const at = root.text.indexOf(" ");
        if (!root.settled || root.stale || at < 0 || root.text.slice(at + 1) === "")
            return;
        Notifications.announce(root.text.slice(0, at) + " Jasper", root.text.slice(at + 1), 1);
    }

    // The lane's prompt guarantees "emoji, space, sentence" — split on the
    // first space (never by character: multi-codepoint emoji like 🌤️ would be
    // cut in half). No space → treat the whole thing as the emoji.
    readonly property int splitAt: text.indexOf(" ")
    readonly property string emoji: splitAt < 0 ? text : text.slice(0, splitAt)
    readonly property string sentence: splitAt < 0 ? "" : text.slice(splitAt + 1)

    // One probe prints "<fresh|stale>\t<insight>"; missing file prints nothing
    // (text stays as-is → hidden on first run before the lane has run once).
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "f=\"${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor/jasper-insight.txt\"; "
            + "[ -f \"$f\" ] || exit 0; "
            + "age=$(( $(date +%s) - $(stat -c %Y \"$f\") )); "
            + "[ \"$age\" -gt 21600 ] && printf 'stale\\t' || printf 'fresh\\t'; "
            + "head -1 \"$f\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const tab = line.indexOf("\t");
                if (tab < 0)
                    return;
                root.stale = line.slice(0, tab) === "stale";
                root.text = line.slice(tab + 1).trim();
            }
        }
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
