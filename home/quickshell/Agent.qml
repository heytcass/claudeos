// Agent.qml — "is ClaudeOS working on itself right now?" signal for the island.
// `active` is true while a rebuild runs (nh — the rebuild wrapper — or a direct
// nixos-rebuild), OR while any process touches the marker file
// $XDG_RUNTIME_DIR/claudeos-agent — the extension point for automations (or a
// heal run) to say "I'm doing something." Polled cheaply.
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
    property bool active: false

    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "if pgrep -x nh >/dev/null 2>&1 || pgrep -x '[.]?nixos-rebuild.*' >/dev/null 2>&1 || [ -e \"$XDG_RUNTIME_DIR/claudeos-agent\" ]; then echo 1; else echo 0; fi"
        ]
        stdout: SplitParser {
            onRead: line => root.active = (line.trim() === "1")
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
