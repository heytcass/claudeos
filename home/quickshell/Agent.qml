// Agent.qml — "what is ClaudeOS doing to itself right now?" signal for the island.
// The protocol (writer helpers in lib/claude-script.nix: claudeos_agent_begin):
// automations drop a per-process file into $XDG_RUNTIME_DIR/claudeos-agent.d/
// whose first line is the activity phrase — "healing …", "preparing the morning
// desk" — and the island shows the newest one. Files older than 60 min are
// ignored (a killed -9 writer can't pulse forever). The legacy single marker
// file $XDG_RUNTIME_DIR/claudeos-agent still works for quick manual use, and
// rebuilds are detected by process as a fallback so plain `nixos-rebuild`/`nh`
// runs pulse too. Polled cheaply.
//
// Matched by process name (pgrep -x, full-comm regex), not cmdline (-f): -f
// would also fire on any shell command that merely mentions "nixos-rebuild"
// (e.g. a monitoring loop — or this probe itself), pinning the pulse on.
// NB: comm is kernel-truncated to 15 chars, and nixos-rebuild-ng's wrapper
// shows as ".nixos-rebuild-" — hence the regex, not a literal name.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // What the machine is doing, e.g. "rebuilding" / "healing" — "" when idle.
    property string activity: ""
    readonly property bool active: activity !== ""

    // Every poll prints exactly one "@<phrase>" line ("@" alone = idle): the
    // sentinel keeps the idle case parseable (SplitParser may drop bare empty
    // lines) and marker content can never be mistaken for no-output.
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "f=$(find \"$XDG_RUNTIME_DIR/claudeos-agent.d\" -maxdepth 1 -type f -mmin -60 -printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-); if [ -n \"$f\" ]; then a=$(head -n1 \"$f\" 2>/dev/null); echo \"@${a:-working}\"; elif [ -e \"$XDG_RUNTIME_DIR/claudeos-agent\" ]; then a=$(head -n1 \"$XDG_RUNTIME_DIR/claudeos-agent\" 2>/dev/null); echo \"@${a:-working}\"; elif pgrep -x nh >/dev/null 2>&1 || pgrep -x '[.]?nixos-rebuild.*' >/dev/null 2>&1; then echo '@rebuilding'; else echo '@'; fi"
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (t.startsWith("@"))
                    root.activity = t.slice(1);
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
