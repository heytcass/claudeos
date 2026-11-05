// Spotlight.qml — "Claude points". Any agent or script can show the user
// WHERE something is instead of describing it: the rest of every monitor dims,
// the target stays clear inside a breathing accent ring, and a short callout
// sits beside it, kept on screen.
//
//   qs ipc call spotlight rect   <x> <y> <w> <h> <text> <ms>
//   qs ipc call spotlight window <address|class> <text> <ms>
//   qs ipc call spotlight clear
//
// Coordinates are Hyprland's global layout (logical) px — what `hyprctl
// clients -j` reports as `at`/`size` — and are converted per monitor below.
// <ms> 0 means the default hold (8 s); every spotlight times out (capped at
// 60 s), so nothing can be left over the screen. Wrapped for lanes as
// `claudeos-spotlight` (modules/apps/spotlight.nix).
//
// It never traps the user: no keyboard focus is taken, and the input mask
// is the callout bubble alone, so every click outside it lands in the app
// underneath. Clicking the callout dismisses.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // The target, in global layout px. Empty (0×0) is allowed: a point.
    property rect target: Qt.rect(0, 0, 0, 0)
    property string callout: ""
    // Up while a spotlight should be showing; `t` is its 0..1 entrance, which
    // also drives the exit fade, so the windows stay mapped until it lands.
    property bool shown: false
    property real t: 0
    readonly property bool live: root.shown || root.t > 0
    // Bumped on every show so a repeat call re-runs the entrance.
    property int serial: 0

    readonly property int defaultMs: 8000
    readonly property int maxMs: 60000

    // The monitor that carries the callout: the one holding the target's
    // centre, else the one nearest to it.
    readonly property string calloutScreen: {
        const cx = root.target.x + root.target.width / 2;
        const cy = root.target.y + root.target.height / 2;
        var best = "", bestD = Infinity;
        for (const s of Quickshell.screens) {
            const dx = Math.max(s.x - cx, 0, cx - (s.x + s.width));
            const dy = Math.max(s.y - cy, 0, cy - (s.y + s.height));
            const d = dx * dx + dy * dy;
            if (d < bestD) {
                bestD = d;
                best = s.name;
            }
        }
        return best;
    }

    function show(x, y, w, h, text, ms) {
        root.target = Qt.rect(x, y, Math.max(0, w), Math.max(0, h));
        root.callout = (text ?? "").toString().slice(0, 280);
        root.serial++;
        exit.stop();
        root.shown = true;
        enter.restart();
        life.interval = ms > 0 ? Math.min(ms, root.maxMs) : root.defaultMs;
        life.restart();
    }
    function clear() {
        if (!root.shown)
            return;
        root.shown = false;
        life.stop();
        enter.stop();
        exit.restart();
    }

    Timer {
        id: life
        onTriggered: root.clear()
    }
    NumberAnimation {
        id: enter
        target: root
        property: "t"
        from: 0
        to: 1
        duration: Motion.emphasis
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.curveStandard
    }
    NumberAnimation {
        id: exit
        target: root
        property: "t"
        to: 0
        duration: Motion.standard
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.curveExit
    }

    // Window lookup: Hyprland's own geometry for the best match. Visible
    // windows only (mapped, not hidden, on a shown workspace) — pointing at
    // a window on another workspace would point at nothing. Address wins,
    // then exact class/initialClass, then a class substring; ties go to the
    // most recently focused. Same rule as claudeos-spotlight's resolver.
    property string pendingText: ""
    property int pendingMs: 0
    property string pendingQuery: ""
    Process {
        id: lookup
        command: ["sh", "-c", "printf '{\"c\":%s,\"m\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    console.warn("spotlight: hyprctl output unreadable");
                    return;
                }
                const shownWs = new Set();
                for (const m of data.m) {
                    shownWs.add(m.activeWorkspace?.id);
                    if (m.specialWorkspace?.id)
                        shownWs.add(m.specialWorkspace.id);
                }
                const q = root.pendingQuery.toLowerCase();
                const addr = q.startsWith("0x") ? q : "0x" + q;
                const cands = data.c.filter(c => c.mapped && !c.hidden && shownWs.has(c.workspace?.id)).sort((a, b) => a.focusHistoryID - b.focusHistoryID);
                const hit = cands.find(c => c.address.toLowerCase() === addr) ?? cands.find(c => c.class.toLowerCase() === q || c.initialClass.toLowerCase() === q) ?? cands.find(c => c.class.toLowerCase().includes(q));
                if (!hit) {
                    console.warn("spotlight: no visible window matches " + root.pendingQuery);
                    return;
                }
                root.show(hit.at[0], hit.at[1], hit.size[0], hit.size[1], root.pendingText, root.pendingMs);
            }
        }
    }

    IpcHandler {
        target: "spotlight"
        function rect(x: int, y: int, w: int, h: int, text: string, ms: int): void {
            root.show(x, y, w, h, text, ms);
        }
        function window(query: string, text: string, ms: int): void {
            root.pendingQuery = query.trim();
            root.pendingText = text;
            root.pendingMs = ms;
            lookup.running = false;
            lookup.running = true;
        }
        function clear(): void {
            root.clear();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData
            visible: root.live
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "claudeos-spotlight"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            readonly property bool hasCallout: root.callout !== "" && root.calloutScreen === modelData.name
            // Clicks pass through everywhere except the callout bubble.
            mask: Region {
                x: bubble.x
                y: bubble.y
                width: win.hasCallout ? bubble.width : 0
                height: win.hasCallout ? bubble.height : 0
            }

            // The target in this monitor's local px, padded so the ring sits
            // just outside it. While entering, the hole starts wide and closes
            // in on the target — the eye follows it there.
            readonly property real pad: 6
            readonly property real grow: (1 - root.t) * 48
            readonly property real hx: root.target.x - modelData.x - pad - grow
            readonly property real hy: root.target.y - modelData.y - pad - grow
            readonly property real hw: root.target.width + 2 * (pad + grow)
            readonly property real hh: root.target.height + 2 * (pad + grow)
            readonly property real hr: Math.min(Theme.radius * 1.5, hw / 2, hh / 2)

            // Dim with a rounded hole: a frame whose border is wider than the
            // screen, so its inner edge (radius − border) is the hole. Big
            // enough to cover the monitor wherever the hole lands, even off it.
            Rectangle {
                readonly property real b: win.width + win.height + Math.abs(win.hx) + Math.abs(win.hy)
                x: win.hx - b
                y: win.hy - b
                width: win.hw + 2 * b
                height: win.hh + 2 * b
                radius: win.hr + b
                color: "transparent"
                border.width: b
                border.color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.55 * root.t)
            }

            // The steady ring, hugging the hole.
            Rectangle {
                x: win.hx - 2
                y: win.hy - 2
                width: win.hw + 4
                height: win.hh + 4
                radius: win.hr + 2
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                opacity: root.t
            }

            // The ping: a second ring that breathes outward and fades, on
            // loop, so the eye finds the target even in peripheral vision.
            Rectangle {
                id: ping
                property real spread: 0
                x: win.hx - 2 - spread
                y: win.hy - 2 - spread
                width: win.hw + 4 + 2 * spread
                height: win.hh + 4 + 2 * spread
                radius: win.hr + 2 + spread
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                opacity: root.t * (1 - spread / 22) * 0.8
                SequentialAnimation on spread {
                    running: root.live
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0
                        to: 22
                        duration: Motion.breathe
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveBreathe
                    }
                    PauseAnimation {
                        duration: Motion.standard
                    }
                }
            }

            // The callout: beside the target — right, else left, else below,
            // else above — and always clamped inside this monitor, clear of
            // the bar.
            Rectangle {
                id: bubble
                visible: win.hasCallout
                readonly property real offset: 24
                readonly property real edge: Theme.gap * 2
                readonly property real topEdge: Theme.barHeight + Theme.gap
                // The settled target (grow = 0), so placement doesn't slide
                // with the entrance.
                readonly property real tx: root.target.x - win.modelData.x - win.pad
                readonly property real ty: root.target.y - win.modelData.y - win.pad
                readonly property real tw: root.target.width + 2 * win.pad
                readonly property real th: root.target.height + 2 * win.pad
                readonly property string side: tx + tw + offset + width <= win.width - edge ? "right" : tx - offset - width >= edge ? "left" : ty + th + offset + height <= win.height - edge ? "below" : "above"
                function clamp(v, lo, hi) {
                    return Math.max(lo, Math.min(hi, v));
                }
                x: clamp(side === "right" ? tx + tw + offset : side === "left" ? tx - offset - width : tx + (tw - width) / 2, edge, win.width - width - edge)
                y: clamp(side === "below" ? ty + th + offset : side === "above" ? ty - offset - height : ty + (th - height) / 2, topEdge, win.height - height - edge)
                width: Math.min(row.implicitWidth, 380) + 28
                height: row.implicitHeight + 20
                radius: Theme.radius
                color: Theme.bgGlass
                border.width: 1
                border.color: Theme.accent
                opacity: root.t
                // Slides the last few px in from the target's side.
                transform: Translate {
                    x: (1 - root.t) * (bubble.side === "right" ? -12 : bubble.side === "left" ? 12 : 0)
                    y: (1 - root.t) * (bubble.side === "below" ? -12 : bubble.side === "above" ? 12 : 0)
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        id: spark
                        text: "✳"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 2
                        anchors.top: parent.top
                    }
                    Text {
                        id: label
                        width: Math.min(implicitWidth, 380 - spark.width - row.spacing)
                        text: root.callout
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clear()
                }
            }
        }
    }
}
