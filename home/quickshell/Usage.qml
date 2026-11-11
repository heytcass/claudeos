pragma Singleton
// The pragma must stay on line 1, above every comment (see Contexts.qml).
// Usage.qml — the bar's face of `claudeos-usage` (modules/apps/usage.nix), the
// local counter of which Claude actions get used. Two jobs:
//   · log(id, source) — fire-and-forget append; never blocks, never fails
//     loudly (a missing binary is just no log line)
//   · counts          — id → uses in the last 30 days, re-read only when the
//     summon opens (refresh), never on a timer; the summon's empty state
//     orders its actions by it
// Ids are lib/action-id.nix slugs, stamped on Keybinds.actions as `id`. The
// summon's own rows log as route:<kind> or "app": never typed text, never which
// app, never a window title.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // id → count over the last 30 days; empty until the first refresh, or
    // with no log yet, in which case callers fall back to registry order.
    property var counts: ({})

    function log(id, source) {
        if (!id)
            return;
        Quickshell.execDetached(["claudeos-usage", "log", id, source]);
    }

    // The registry id of the action behind a quickshell global, or "" (an
    // older deployed Keybinds.qml has no ids).
    function idForGlobal(g) {
        const a = (Keybinds.actions ?? []).find(x => x.global === g);
        return a && a.id ? a.id : "";
    }

    function refresh() {
        reader.running = true;
    }

    Process {
        id: reader
        command: ["claudeos-usage", "counts", "--days", "30"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {};
                const lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    const p = lines[i].split("\t");
                    if (p.length === 2)
                        m[p[0]] = parseInt(p[1]) || 0;
                }
                root.counts = m;
            }
        }
    }
}
