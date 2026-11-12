pragma Singleton
// Health.qml — the failed claudeos-* / claude-* systemd units (user or system),
// one probe for the whole shell. HealthWidget (one per monitor's right pill)
// and NeedsYou (the island's queue) both read it; before this the probe lived
// inside HealthWidget, so every monitor ran its own copy and nothing else could
// see the result.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Space-separated failed unit names ("" = all healthy).
    property string failed: ""
    readonly property var failedList: failed === "" ? [] : failed.split(" ")

    // "Show me the failed units": HealthWidget on the focused monitor opens its
    // popup. The island's queue rows use this as their way in.
    signal popupRequested
    function openPopup() {
        root.popupRequested();
    }

    // Sentinel-prefixed single line per poll ("@" alone = healthy), same
    // contract as Agent.qml — bare empty lines can be dropped by the parser.
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "echo \"@$({ systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } 2>/dev/null | awk '{print $1}' | grep -E '^(claudeos|claude)-' | paste -sd' ' -)\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (t.startsWith("@") && t.slice(1).trim() !== root.failed)
                    root.failed = t.slice(1).trim();
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
