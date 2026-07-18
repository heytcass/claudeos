// StatusWidget.qml — the bar's window onto status.claude.com. A small dot that
// follows Anthropic's public Statuspage: dim-green and steady while everything
// is operational (present, but quiet — you can *follow* it without it nagging),
// then bright and breathing the moment an indicator goes minor/major/critical.
// Click for the per-service breakdown and any open incidents.
//
// One HTTPS GET of /api/v2/summary.json per poll feeds both the dot and the
// popup: it carries the overall `status.indicator` plus every component's state
// and the list of unresolved incidents. Same Process+Timer+sentinel contract as
// HealthWidget/ClaudeUsageWidget — a line is always "@"-prefixed; "@" alone
// (offline, DNS down, API hiccup) means "no data", which hides the widget so it
// never shows a stale or false green.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Statuspage overall indicator: none | minor | major | critical | maintenance.
    // "" = no data yet / unreachable.
    property string indicator: ""
    property string description: ""
    // Per-component [{n: name, s: status}], and open incidents [{n, s: impact}].
    property var components: []
    property var incidents: []

    readonly property bool operational: indicator === "none"
    readonly property bool hasData: indicator !== ""

    // Severity → base16. Green when all clear, amber for minor degradation,
    // red for major/critical, blue for maintenance. Never a hardcoded hex.
    readonly property color statusColor: {
        switch (indicator) {
        case "none":
            return Theme.good;
        case "minor":
            return Theme.warn;
        case "major":
        case "critical":
            return Theme.urgent;
        case "maintenance":
            return Theme.accent;
        default:
            return Theme.muted;
        }
    }

    visible: hasData
    implicitWidth: visible ? dot.width + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "OUT=$(curl -sf -m 10 https://status.claude.com/api/v2/summary.json 2>/dev/null | jq -c '{i: .status.indicator, d: .status.description, c: [.components[] | select(.showcase==true and .group==false) | {n: .name, s: .status}], inc: [.incidents[] | {n: .name, s: .impact}]}' 2>/dev/null); echo \"@$OUT\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t.startsWith("@"))
                    return;
                const body = t.slice(1).trim();
                if (body === "") {
                    root.indicator = "";
                    root.description = "";
                    root.components = [];
                    root.incidents = [];
                    return;
                }
                try {
                    const d = JSON.parse(body);
                    root.indicator = d.i || "";
                    root.description = d.d || "";
                    root.components = d.c || [];
                    root.incidents = d.inc || [];
                } catch (e) {
                    root.indicator = "";
                    root.description = "";
                    root.components = [];
                    root.incidents = [];
                }
            }
        }
    }
    Timer {
        interval: 180000 // 3 min — one cached HTTPS GET, cheap
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: root.statusColor
        // Quiet when operational (steady, dimmed); breathe to catch the eye the
        // moment anything is degraded.
        opacity: root.operational ? 0.55 : 1
        SequentialAnimation on opacity {
            running: root.visible && !root.operational
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: col.implicitWidth + 28
        implicitHeight: col.implicitHeight + 20
        visible: false
        grabFocus: true
        color: "transparent"

        // Component status → colour, mirroring the top-level severity mapping.
        function compColor(s) {
            switch (s) {
            case "operational":
                return Theme.good;
            case "degraded_performance":
                return Theme.warn;
            case "partial_outage":
                return Theme.warn;
            case "major_outage":
                return Theme.urgent;
            case "under_maintenance":
                return Theme.accent;
            default:
                return Theme.subtext;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "claude status"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    text: root.description || "—"
                    color: root.statusColor
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                }

                // Thin divider before the per-service list.
                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                    visible: root.components.length > 0
                }

                Repeater {
                    model: root.components
                    delegate: Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: popup.compColor(modelData.s)
                        }
                        Text {
                            text: modelData.n
                            color: modelData.s === "operational" ? Theme.subtext : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                }

                // Open incidents, if any — impact-coloured, above the fold.
                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                    visible: root.incidents.length > 0
                }
                Repeater {
                    model: root.incidents
                    delegate: Text {
                        required property var modelData
                        text: "⚠ " + modelData.n
                        color: modelData.s === "critical" || modelData.s === "major" ? Theme.urgent : Theme.warn
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                        width: 260
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
