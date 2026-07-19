// Contexts.qml — the task-contexts model (Phase 3). One small singleton the bar
// reads two ways:
//   · activeName → the context you're currently IN, shown at low emphasis in the
//     island's idle face. Derived, not stored: `restore` names the Hyprland
//     workspace after the context slug, so the focused workspace's name IS the
//     active context. No extra state file, no polling for it — it rides
//     Hyprland's reactive focusedWorkspace binding.
//   · contexts  → [{slug, name}] of everything saved, for the intent line's
//     `resume <name>` route to prefix-match against (so "resume the refi" knows
//     it's a context and not a task). This IS polled — the manifest dir changes
//     only on save/rm, so a lazy 12s cadence is plenty.
// No model calls: pure file/IPC reads, same discipline as Presence.qml. jq is
// not assumed on the shell's PATH (the probe only concatenates; QML parses).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // [{slug, name}] — every saved context.
    property var contexts: []

    // The focused workspace's name (reactive via Hyprland IPC). A restored
    // context's workspace is named after its slug, so this is how we know where
    // we are.
    readonly property string focusedWsName: Hyprland.focusedWorkspace?.name ?? ""

    // The display name of the context we're currently in, or "" if the focused
    // workspace isn't a known context (a numbered/scratch workspace).
    readonly property string activeName: {
        const w = focusedWsName;
        const list = contexts || [];
        for (var i = 0; i < list.length; i++)
            if (list[i].slug === w)
                return list[i].name;
        return "";
    }

    // Resolve the text after "resume " to a context slug, or "" if it matches
    // none. Exact name/slug wins; otherwise a UNIQUE prefix (ambiguous → "",
    // so the intent line leaves it as a task rather than guessing). The CLI
    // resolves independently too — this is only for the bar's route prediction.
    function resolveResume(text) {
        const q = (text || "").trim().toLowerCase();
        if (q === "")
            return "";
        const list = contexts || [];
        for (var i = 0; i < list.length; i++)
            if (list[i].slug === q || (list[i].name || "").toLowerCase() === q)
                return list[i].slug;
        var hits = [];
        for (var j = 0; j < list.length; j++) {
            const c = list[j];
            if (c.slug.startsWith(q) || (c.name || "").toLowerCase().startsWith(q))
                hits.push(c.slug);
        }
        return hits.length === 1 ? hits[0] : "";
    }

    // --- poll the manifest dir ------------------------------------------------
    // Each line is "<slug>\t<compact-json>"; the writer (claudeos_context_install)
    // stores one-line JSON, so cat yields exactly one line per context. A bare
    // "END" commits the batch, so an empty dir correctly clears to [].
    property var _cb: []
    Process {
        id: probe
        command: ["sh", "-c", "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/claudeos/contexts\"; for f in \"$d\"/*.json; do [ -e \"$f\" ] || continue; b=\"${f##*/}\"; b=\"${b%.json}\"; printf '%s\\t' \"$b\"; cat \"$f\"; done; printf 'END\\n'"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root.contexts = root._cb;
                    root._cb = [];
                    return;
                }
                const i = line.indexOf("\t");
                if (i < 0)
                    return;
                const slug = line.slice(0, i);
                try {
                    const obj = JSON.parse(line.slice(i + 1));
                    root._cb.push({
                        slug: slug,
                        name: obj.name || slug
                    });
                } catch (e) {
                // a half-written line during a save race — skip; next poll settles.
                }
            }
        }
    }
    Timer {
        interval: 12000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
