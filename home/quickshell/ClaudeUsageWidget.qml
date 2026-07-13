// ClaudeUsageWidget.qml — the system's fuel gauge for its own brain. A small
// ring showing the Claude subscription's 5-hour session usage, quiet until it
// matters: muted below 70%, accent to 90%, warn above. The percent number only
// appears once attention is warranted. Click lists every limit with its reset
// time. Polls the same OAuth endpoint `claude /usage` reads, via the
// credentials file Claude Code maintains — the token stays in a shell
// variable, never in argv. Same Process+Timer+sentinel contract as
// HealthWidget: "@" alone means no data (logged out, offline), which hides
// the widget entirely.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // -1 = unknown/absent. `scoped` is the per-model weekly limit (e.g. a
    // preview model's allowance) — present only when the account has one.
    property int session: -1
    property int weekly: -1
    property int scoped: -1
    property string sessionReset: ""
    property string weeklyReset: ""
    property string scopedReset: ""

    readonly property int maxPct: Math.max(session, weekly, scoped)
    readonly property color gaugeColor: maxPct >= 90 ? Theme.warn : maxPct >= 70 ? Theme.accent : Theme.subtext

    visible: session >= 0 || weekly >= 0
    implicitWidth: visible ? row.implicitWidth + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' \"$HOME/.claude/.credentials.json\" 2>/dev/null); " + "if [ -z \"$TOKEN\" ]; then echo @; exit 0; fi; " + "OUT=$(curl -sf -m 10 -H \"Authorization: Bearer $TOKEN\" -H 'anthropic-beta: oauth-2025-04-20' https://api.anthropic.com/api/oauth/usage 2>/dev/null | jq -c '{s: ([.limits[] | select(.kind==\"session\")][0].percent // -1), w: ([.limits[] | select(.kind==\"weekly_all\")][0].percent // -1), f: ([.limits[] | select(.kind==\"weekly_scoped\")][0].percent // -1), sr: ([.limits[] | select(.kind==\"session\")][0].resets_at // \"\"), wr: ([.limits[] | select(.kind==\"weekly_all\")][0].resets_at // \"\"), fr: ([.limits[] | select(.kind==\"weekly_scoped\")][0].resets_at // \"\")}' 2>/dev/null); " + "echo \"@$OUT\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t.startsWith("@"))
                    return;
                const body = t.slice(1).trim();
                if (body === "") {
                    root.session = -1;
                    root.weekly = -1;
                    root.scoped = -1;
                    return;
                }
                try {
                    const d = JSON.parse(body);
                    root.session = d.s;
                    root.weekly = d.w;
                    root.scoped = d.f;
                    root.sessionReset = d.sr;
                    root.weeklyReset = d.wr;
                    root.scopedReset = d.fr;
                    ring.requestPaint();
                } catch (e) {
                    root.session = -1;
                    root.weekly = -1;
                    root.scoped = -1;
                }
            }
        }
    }
    Timer {
        interval: 300000 // 5 min — one HTTPS request, nothing polls an LLM
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Canvas {
            id: ring
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const r = c - 1.5;
                const pct = Math.max(0, root.session) / 100;
                ctx.lineWidth = 2.5;
                ctx.lineCap = "round";
                // track
                ctx.beginPath();
                ctx.arc(c, c, r, 0, 2 * Math.PI);
                ctx.strokeStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.3);
                ctx.stroke();
                // session fill, from 12 o'clock
                if (pct > 0) {
                    ctx.beginPath();
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + pct * 2 * Math.PI);
                    ctx.strokeStyle = root.gaugeColor;
                    ctx.stroke();
                }
            }
            Connections {
                target: root
                function onGaugeColorChanged() {
                    ring.requestPaint();
                }
            }
        }

        // The number earns its pixels only when something is worth knowing.
        Text {
            visible: root.maxPct >= 70
            anchors.verticalCenter: parent.verticalCenter
            text: root.maxPct + "%"
            color: root.gaugeColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize - 2
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

        // "→ Mon 11:00 AM" for far resets, "→ 11:59 PM" for today's
        function fmtReset(iso) {
            if (!iso)
                return "";
            const d = new Date(iso);
            const far = (d - new Date()) > 22 * 3600 * 1000;
            return "→ " + d.toLocaleString(Qt.locale(), far ? "ddd h:mm AP" : "h:mm AP");
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
                    text: "claude usage"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Repeater {
                    model: [
                        {
                            label: "session (5h)",
                            pct: root.session,
                            reset: root.sessionReset
                        },
                        {
                            label: "weekly",
                            pct: root.weekly,
                            reset: root.weeklyReset
                        },
                        {
                            label: "model weekly",
                            pct: root.scoped,
                            reset: root.scopedReset
                        }
                    ]
                    delegate: Text {
                        required property var modelData
                        visible: modelData.pct >= 0
                        text: modelData.label + "  " + modelData.pct + "%  " + popup.fmtReset(modelData.reset)
                        color: modelData.pct >= 90 ? Theme.warn : modelData.pct >= 70 ? Theme.accent : Theme.subtext
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
