// IntentLine.qml — one input that routes itself (Phase 2a: deterministic only).
// SUPER+R summons a centered capsule (Hyprland: `bind = $mod, R, global,
// quickshell:intent`). As you type it classifies the text with ZERO model calls
// and shows the predicted route BEFORE you commit — predictable, auditable:
//   $command   → run it in a terminal
//   app name   → launch the matching desktop entry (exact / prefix match)
//   question?  → claude-ask-desktop (the answer returns as a notification)
//   otherwise  → the wish lane (claude-wish → a reviewed wish/* PR)
// Tab reroutes to any other route; every route is visible before Enter. Carries
// the island's agent-glow language (breathing accent, soft halo) and, for the
// async routes (ask / wish), the genie exit into the island. Esc or click-away
// dismisses.
//
// This is "a better fuzzel, honestly assessed": app/$cmd resolve at launcher
// speed with no model in the loop. 2b adds the haiku router + a dedicated task
// lane behind the "otherwise" arm; 2a keeps that arm pointed at the proven wish
// lane, so the surface earns its keep on day one. fuzzel keeps SUPER+Space and
// the wish overlay keeps SUPER+W until this earns those binds (daily-driver rule).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root
    property bool shown: false
    property bool sent: false
    // Tab override: "" follows the predicted (auto) route; else forces a route.
    property string forced: ""

    GlobalShortcut {
        appid: "quickshell"
        name: "intent"
        description: "Intent line — type an app, a command, a question, or a wish"
        onPressed: {
            root.forced = "";
            root.sent = false;
            root.shown = !root.shown;
        }
    }

    // ---- deterministic classification (pure JS, no model call ever) ----

    readonly property string qt: input.text.trim()

    // Best desktop-entry match for the current text: an exact name/id wins, else
    // the first prefix match. Deliberately conservative — no loose fuzzy — so a
    // real sentence falls through to the wish route instead of launching
    // something that merely shares a few letters.
    function bestApp(text) {
        const q = text.trim().toLowerCase();
        if (q.length < 2)
            return null;
        const apps = DesktopEntries.applications.values;
        var prefix = null;
        for (var i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay)
                continue;
            const n = (e.name || "").toLowerCase();
            const id = (e.id || "").toLowerCase();
            if (n === q || id === q)
                return e;                 // exact — launch this
            if (prefix === null && (n.startsWith(q) || id.startsWith(q)))
                prefix = e;
        }
        return prefix;
    }
    readonly property var appMatch: bestApp(qt)

    // A leading interrogative (or aux verb) reads as a question even without "?".
    // The \b guards app names: "dolphin"/"docker" don't match "do\b".
    function isQuestion(t) {
        return /^(what|why|how|who|when|where|which|whose|is|are|am|do|does|did|can|could|should|would|will|may|might)\b/.test(t.toLowerCase());
    }

    // The route predicted from the text alone.
    readonly property string autoRoute: {
        const t = qt;
        if (t === "")
            return "none";
        if (t.charAt(0) === "$")
            return "cmd";
        if (t.charAt(t.length - 1) === "?")
            return "ask";                 // an explicit question wins over an app name
        if (appMatch)
            return "app";
        if (isQuestion(t))
            return "ask";
        return "task";
    }
    // The committed route: a Tab override for the current text, else the prediction.
    readonly property string route: (forced !== "" && qt !== "") ? forced : autoRoute

    // Concrete routes Tab cycles through (app only when something actually matches).
    readonly property var routeRing: (appMatch ? ["app"] : []).concat(["cmd", "ask", "task"])
    function cycleForced(dir) {
        if (qt === "")
            return;
        const ring = routeRing;
        var i = ring.indexOf(route);
        if (i < 0)
            i = 0;
        root.forced = ring[(i + dir + ring.length) % ring.length];
    }

    // ---- per-route affordances (all colours from the Theme singleton) ----

    function routeColor(r) {
        if (r === "cmd")
            return Theme.good;            // green — a terminal
        if (r === "ask")
            return Theme.base0C;          // cyan — a question
        if (r === "task")
            return Theme.accentAlt;       // the wish accent
        return Theme.accent;              // app + none
    }
    function routeGlyph(r) {
        if (r === "cmd")
            return "❯";              // ❯
        if (r === "ask")
            return "?";
        if (r === "task")
            return "✳";              // ✳ — the house wish asterisk
        return "→";                  // → — app fallback when it has no icon
    }
    function routeLabel(r) {
        if (r === "none")
            return "an app  ·  a $command  ·  a question?  ·  or a wish";
        if (r === "cmd")
            return "run in a terminal";
        if (r === "ask")
            return "ask Claude — the answer returns as a notification";
        if (r === "task")
            return "make a wish — it arrives as a pull request";
        return "launch " + (appMatch ? appMatch.name : "app");
    }
    function routeVerb(r) {
        if (r === "cmd")
            return "run";
        if (r === "ask")
            return "ask";
        if (r === "task")
            return "wish";
        return "launch";
    }
    // App icon for the leading indicator (existence-checked; "" → fall back to a glyph).
    readonly property string appIcon: (route === "app" && appMatch) ? Quickshell.iconPath(appMatch.icon, true) : ""

    // ---- commit & dismiss ----

    function reset() {
        root.shown = false;
        root.sent = false;
        root.forced = "";
        input.text = "";
    }

    function commit() {
        const t = input.text.trim();
        if (t === "" || root.sent)
            return;
        const r = root.route;
        if (r === "app") {
            if (!appMatch)
                return;
            appMatch.execute();           // launch detached; deterministic, instant
            reset();
        } else if (r === "cmd") {
            const cmd = t.slice(1).trim();
            if (cmd === "")
                return;
            // Hold the terminal open after the command so its output is readable.
            Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", cmd + "; echo; echo '[press enter to close]'; read"]);
            reset();
        } else if (r === "ask") {
            // claude-ask-desktop takes an optional query arg (no arg → its own
            // zenity prompt, still Super+A); pass the sentence straight through.
            Quickshell.execDetached(["claude-ask-desktop", t]);
            root.sent = true;
            flight.start();               // the question flies into the island; the answer returns as a notification
        } else {
            // task → the wish lane. 2b splits wish vs task via a haiku router;
            // in 2a every unrouted sentence lands in the proven wish lane.
            Quickshell.execDetached(["claude-wish", t]);
            root.sent = true;
            flight.start();
        }
    }

    // The genie exit (async routes only): the capsule flies up into the island —
    // the request visibly enters the machine, which starts breathing a beat later.
    ParallelAnimation {
        id: flight
        NumberAnimation {
            target: card
            property: "scale"
            to: 0.06
            duration: 480
            easing.type: Easing.InBack
        }
        NumberAnimation {
            target: card
            property: "anchors.verticalCenterOffset"
            to: -(win.height / 2) + Theme.barHeight
            duration: 480
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0.15
            duration: 480
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.reset();
            card.scale = 1;
            card.opacity = 1;
            card.anchors.verticalCenterOffset = 0;
        }
    }

    PanelWindow {
        id: win
        visible: root.shown
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        onVisibleChanged: if (visible)
            input.forceActiveFocus()

        // dim backdrop — click anywhere to dismiss
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.reset()
            }
        }

        // the capsule, breathing like the island does while an agent works; its
        // accent shifts to the predicted route's colour, so the route is legible
        // from the border alone.
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 560
            height: col.implicitHeight + 52
            radius: 20
            color: Theme.bg
            border.width: 2
            border.color: Qt.rgba(root.routeColor(root.route).r, root.routeColor(root.route).g, root.routeColor(root.route).b, 0.4 + 0.45 * glow)

            Behavior on border.color {
                ColorAnimation {
                    duration: 220
                }
            }

            property real glow: 0
            SequentialAnimation on glow {
                running: root.shown
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
            }

            // halo layers, painted below the capsule, tinted by the route
            Repeater {
                model: [
                    {
                        pad: 16,
                        alpha: 0.13
                    },
                    {
                        pad: 34,
                        alpha: 0.05
                    }
                ]
                delegate: Rectangle {
                    required property var modelData
                    z: -1
                    anchors.centerIn: parent
                    width: card.width + modelData.pad + 10 * card.glow
                    height: card.height + modelData.pad + 10 * card.glow
                    radius: 30
                    color: Qt.rgba(root.routeColor(root.route).r, root.routeColor(root.route).g, root.routeColor(root.route).b, modelData.alpha * (0.4 + 0.6 * card.glow))
                }
            }

            Column {
                id: col
                anchors.centerIn: parent
                width: card.width - 52
                spacing: 12

                // header: the predicted-route indicator + a small status word
                Row {
                    spacing: 10

                    // app icon when the route resolves to a real entry, else the
                    // route glyph in the route's colour.
                    Item {
                        width: Theme.fontSize + 10
                        height: Theme.fontSize + 10
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.fill: parent
                            visible: root.appIcon !== ""
                            source: root.appIcon
                            sourceSize.width: Theme.fontSize + 10
                            sourceSize.height: Theme.fontSize + 10
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.appIcon === ""
                            text: root.routeGlyph(root.route)
                            color: root.routeColor(root.route)
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 6
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sent ? (root.route === "ask" ? "asking Claude…" : "wishing…") : "intent"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 5
                    }
                }

                // the input capsule
                Rectangle {
                    visible: !root.sent
                    width: parent.width
                    height: 44
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 2
                        clip: true

                        // typing resets any Tab override, so the prediction stays honest
                        onTextChanged: root.forced = ""
                        onAccepted: root.commit()
                        Keys.onEscapePressed: root.reset()
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Tab) {
                                root.cycleForced(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                root.cycleForced(-1);
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: "app, $command, a question?, or a wish"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 2
                        }
                    }
                }

                // the predicted route, in plain words — the thing you're about to
                // commit, visible before you commit it.
                Row {
                    visible: !root.sent
                    spacing: 8
                    Text {
                        text: "→"
                        color: root.routeColor(root.route)
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        text: root.routeLabel(root.route)
                        color: root.route === "none" ? Theme.subtext : Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize
                    }
                }

                // footer hint — the verb tracks the route, so Enter never surprises
                Text {
                    visible: !root.sent
                    text: root.qt === "" ? "Enter to route  ·  Esc to dismiss" : "Enter to " + root.routeVerb(root.route) + "  ·  Tab to reroute  ·  Esc to dismiss"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    visible: root.sent
                    text: root.route === "ask" ? "✨ the answer will arrive as a notification" : "✨ the machine is working on it — watch the island, then the bar's ✻"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }
}
