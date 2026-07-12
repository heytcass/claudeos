// Agent.qml — "what is ClaudeOS doing to itself right now?" signal for the island.
// The marker file $XDG_RUNTIME_DIR/claudeos-agent is the protocol: any automation
// (heal, morning-desk, auto-update, a Claude session hook) writes a short phrase
// into it — "healing", "morning desk" — and the island shows it. An empty marker
// still counts (phrase defaults to "working"). Rebuilds are detected by process
// as a fallback so plain `nixos-rebuild`/`nh` runs pulse too. Polled cheaply.
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
            "if [ -e \"$XDG_RUNTIME_DIR/claudeos-agent\" ]; then a=$(head -n1 \"$XDG_RUNTIME_DIR/claudeos-agent\" 2>/dev/null); echo \"@${a:-working}\"; elif pgrep -x nh >/dev/null 2>&1 || pgrep -x '[.]?nixos-rebuild.*' >/dev/null 2>&1; then echo '@rebuilding'; else echo '@'; fi"
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
