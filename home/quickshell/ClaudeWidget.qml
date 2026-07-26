// ClaudeWidget.qml — one bar element for "how is Claude doing right now",
// merging what used to be two: status.claude.com's dot (StatusWidget) and the
// subscription usage ring (ClaudeUsageWidget). Same two independent
// Process+Timer probes as before, but now one *mark* rather than two adjacent
// ones: a usage ring wrapped around a Claude spark.
//
// The two variables are orthogonal, so they get orthogonal channels of a single
// glyph — arc extent + arc colour say how much of *your* budget is gone, the
// core's colour says how *their* service is doing. Tempting as it is to tint the
// whole ring by service status, that would overload one channel: a red ring
// would mean either "you're nearly capped" or "Anthropic is down", and you'd
// have to open the popup to find out which.
//
// Each half still hides itself with the "@"-alone sentinel (offline/no data) —
// ring alone, spark alone, or nothing at all — and the whole widget disappears
// only when *both* are silent.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ---- status.claude.com ----
    // Statuspage overall indicator: none | minor | major | critical | maintenance.
    // "" = no data yet / unreachable.
    property string indicator: ""
    property string description: ""
    property var components: []
    property var incidents: []

    readonly property bool operational: indicator === "none"
    readonly property bool hasStatus: indicator !== ""

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

    // ---- subscription usage ----
    // -1 = unknown/absent. `scoped` is the per-model weekly limit (e.g. a
    // preview model's allowance) — present only when the account has one.
    property int session: -1
    property int weekly: -1
    property int scoped: -1
    property string sessionReset: ""
    property string weeklyReset: ""
    property string scopedReset: ""

    readonly property bool hasUsage: session >= 0 || weekly >= 0
    // The binding constraint — whichever limit runs out first. The ring and the
    // number both read from this, so they can never disagree (they used to: the
    // ring drew `session` while the label printed the max, so a hot weekly cap
    // showed as a nearly-empty ring next to a loud "85%").
    readonly property int maxPct: Math.max(session, weekly, scoped)
    readonly property color gaugeColor: maxPct >= 90 ? Theme.warn : maxPct >= 70 ? Theme.accent : Theme.subtext

    visible: hasStatus || hasUsage
    implicitWidth: visible ? row.implicitWidth + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Process {
        id: statusProbe
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
        onTriggered: statusProbe.running = true
    }

    Process {
        id: usageProbe
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
                    ringCanvas.requestPaint();
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
        onTriggered: usageProbe.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // ---- the merged glyph: usage ring wrapped around a Claude spark ----
        // Two concentric layers rather than two siblings, so the pair reads as
        // one object. The spark also makes the widget self-identifying: in a row
        // of drawn gauges, an anonymous ring needs decoding, a spark doesn't.
        Item {
            id: glyph
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            // Sweep the arc instead of snapping it. The probe is a 5-minute
            // poll, so an 8-point jump appears all at once — animated it reads
            // as a measurement settling, unanimated it reads as a glitch.
            property real arcPct: root.hasUsage ? Math.max(0, root.maxPct) : 0
            Behavior on arcPct {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.InOutCubic
                }
            }
            onArcPctChanged: ringCanvas.requestPaint()

            Canvas {
                id: ringCanvas
                anchors.fill: parent
                visible: root.hasUsage
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2;
                    const r = c - 2.25; // leaves the outer stroke a 1px margin
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    // Track — the unspent remainder, and the arc's reference
                    // frame: without a visible track you can't judge what
                    // fraction the arc covers. 0.35 alpha is a deliberate
                    // balance — it puts the track ~1.8:1 against the bar (present
                    // but recessive) while the calm arc (Theme.subtext) still
                    // clears it by ~4.5:1. Dropping it further makes the arc pop
                    // but costs the gauge its baseline.
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, 2 * Math.PI);
                    ctx.strokeStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35);
                    ctx.stroke();
                    // spent fill, from 12 o'clock
                    const pct = glyph.arcPct / 100;
                    if (pct > 0) {
                        ctx.beginPath();
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + pct * 2 * Math.PI);
                        ctx.strokeStyle = root.gaugeColor;
                        ctx.stroke();
                    }
                }
            }

            Canvas {
                id: sparkCanvas
                anchors.centerIn: parent
                width: 10
                height: 10
                visible: root.hasStatus
                // Quiet when operational (steady, dimmed); breathe to catch the
                // eye the moment anything is degraded.
                opacity: root.operational ? 0.7 : 1
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2;
                    ctx.strokeStyle = root.statusColor;
                    ctx.lineWidth = 1.1;
                    ctx.lineCap = "round";
                    // Six rays: enough to read as the Claude spark, few enough
                    // that they stay distinct at 10px inside the ring.
                    for (let i = 0; i < 6; i++) {
                        const a = (i * 60 - 90) * Math.PI / 180;
                        ctx.beginPath();
                        ctx.moveTo(c + Math.cos(a) * 0.6, c + Math.sin(a) * 0.6);
                        ctx.lineTo(c + Math.cos(a) * 3.4, c + Math.sin(a) * 3.4);
                        ctx.stroke();
                    }
                }
                SequentialAnimation on opacity {
                    running: sparkCanvas.visible && !root.operational
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.4
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

            // One listener for both canvases. The `operational` restore matters:
            // `SequentialAnimation on opacity` destroys the declarative binding
            // when it takes the property, so recovery from an incident would
            // otherwise leave the spark stuck at whatever opacity it stopped on.
            Connections {
                target: root
                function onGaugeColorChanged() {
                    ringCanvas.requestPaint();
                }
                function onStatusColorChanged() {
                    sparkCanvas.requestPaint();
                }
                function onOperationalChanged() {
                    if (root.operational)
                        sparkCanvas.opacity = 0.7;
                }
            }
        }

        // The number earns its pixels only when something is worth knowing.
        Text {
            visible: root.hasUsage && root.maxPct >= 70
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

                // ---- status section ----
                Text {
                    visible: root.hasStatus
                    text: "claude status"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    visible: root.hasStatus
                    text: root.description || "—"
                    color: root.statusColor
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                    visible: root.hasStatus && root.components.length > 0
                }
                Repeater {
                    model: root.hasStatus ? root.components : []
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
                    visible: root.hasStatus && root.incidents.length > 0
                }
                Repeater {
                    model: root.hasStatus ? root.incidents : []
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

                // ---- divider between the two sections ----
                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                    visible: root.hasStatus && root.hasUsage
                }

                // ---- usage section ----
                Text {
                    visible: root.hasUsage
                    text: "claude usage"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Repeater {
                    model: root.hasUsage ? [
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
                    ] : []
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
