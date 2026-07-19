// IntentLine.qml — one input that routes itself (Phase 2a: deterministic only).
// SUPER+R summons a centered capsule (Hyprland: `bind = $mod, R, global,
// quickshell:intent`). As you type it classifies the text with ZERO model calls
// and shows the predicted route BEFORE you commit — predictable, auditable:
//   $command    → run it in a terminal
//   app name    → launch the matching desktop entry (exact / prefix match)
//   question?   → claude-ask-desktop (the answer returns as a notification)
//   save as <n> → snapshot this workspace as a task context (Phase 3)
//   resume <n>  → reassemble a saved context onto its named workspace (Phase 3)
//   otherwise   → the intent router (claudeos-intent, Phase 2b): one haiku call
//                 picks wish (→ a reviewed PR) vs task (→ a reviewable artifact)
// Tab reroutes to any other route; every route is visible before Enter. Carries
// the island's agent-glow language (breathing accent, soft halo) and, for the
// async routes (ask / otherwise), the genie exit into the island. Esc or
// click-away dismisses.
//
// This is "a better fuzzel, honestly assessed": app/$cmd resolve at launcher
// speed with no model in the loop. The "otherwise" arm is the only one that
// spends a model call, and only after deterministic classification declined —
// it hands off to claudeos-intent (haiku router + task lane). fuzzel keeps
// SUPER+Space and the wish overlay keeps SUPER+W until this earns those binds
// (daily-driver rule).
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

    // Best desktop-entry match for the current text, ranked best-first:
    //   exact name/id  >  full-string prefix  >  interior word prefix
    //   >  keyword / generic-name word  >  loose substring
    // Interior words matter: "chrome" must find "Google Chrome", "code" →
    // "Visual Studio Code". Still deliberately conservative — every tier is
    // anchored at a WORD boundary (or a substring of a single token), so a
    // real multi-word sentence matches nothing here and falls through to the
    // wish route instead of launching something that merely shares letters.
    // Within a tier the shortest name is the most specific, so it wins.
    function bestApp(text) {
        const q = text.trim().toLowerCase();
        if (q.length < 2)
            return null;
        function words(s) {
            return (s || "").toLowerCase().split(/[\s._\-]+/).filter(Boolean);
        }
        const apps = DesktopEntries.applications.values;
        var tiers = [[], [], [], []];   // 0 prefix · 1 word-prefix · 2 keyword · 3 substring
        for (var i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay)
                continue;
            const n = (e.name || "").toLowerCase();
            const id = (e.id || "").toLowerCase();
            if (n === q || id === q)
                return e;                                  // exact — launch this
            if (n.startsWith(q) || id.startsWith(q)) {
                tiers[0].push(e);
                continue;
            }
            if (words(n).some(w => w.startsWith(q)) || words(id).some(w => w.startsWith(q))) {
                tiers[1].push(e);                          // "chrome" → "Google Chrome"
                continue;
            }
            const extra = (e.keywords || []).concat([e.genericName || ""]);
            if (extra.some(k => words(k).some(w => w.startsWith(q)))) {
                tiers[2].push(e);                          // "browser" → generic name
                continue;
            }
            if (n.includes(q)) {
                tiers[3].push(e);
                continue;
            }
        }
        for (var t = 0; t < tiers.length; t++) {
            if (tiers[t].length)
                return tiers[t].reduce((a, b) => ((b.name || "").length < (a.name || "").length ? b : a));
        }
        return null;
    }
    readonly property var appMatch: bestApp(qt)

    // ---- context routes (Phase 3): "save as <name>" / "resume <name>" ----
    // Deterministic, zero model calls. `save as` always matches (it NAMES a new
    // context); `resume` matches only when <name> resolves to a KNOWN context
    // (Contexts.resolveResume), so "resume normal life" stays a task rather than
    // hijacking a legitimate sentence.
    readonly property var saveMatch: qt.match(/^save as\s+(.+)$/i)
    readonly property string saveName: saveMatch ? saveMatch[1].trim() : ""
    readonly property var resumeMatch: qt.match(/^resume\s+(.+)$/i)
    readonly property string resumeSlug: resumeMatch ? Contexts.resolveResume(resumeMatch[1]) : ""
    readonly property string resumeName: {
        const list = Contexts.contexts || [];
        for (var i = 0; i < list.length; i++)
            if (list[i].slug === resumeSlug)
                return list[i].name;
        return resumeSlug;
    }

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
        if (saveName !== "")
            return "save";                // "save as <name>" — snapshot this workspace
        if (resumeSlug !== "")
            return "resume";              // "resume <known context>" — reassemble it
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
        // The explicit context prefixes aren't part of the Tab ring — leave them.
        if (autoRoute === "save" || autoRoute === "resume")
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
            return Theme.accentAlt;       // the wish/task accent
        if (r === "save")
            return Theme.base0A;          // amber — capturing this workspace
        if (r === "resume")
            return Theme.base0E;          // violet — reassembling a saved context
        return Theme.accent;              // app + none
    }
    function routeGlyph(r) {
        if (r === "cmd")
            return "❯";              // ❯
        if (r === "ask")
            return "?";
        if (r === "task")
            return "✳";              // ✳ — the house asterisk; the machine takes it from here
        if (r === "save")
            return "⊕";              // ⊕ — capture the current workspace
        if (r === "resume")
            return "⟳";              // ⟳ — reassemble a saved one
        return "→";                  // → — app fallback when it has no icon
    }
    function routeLabel(r) {
        if (r === "none")
            return "an app  ·  a $command  ·  a question?  ·  or a task";
        if (r === "cmd")
            return "run in a terminal";
        if (r === "ask")
            return "ask Claude — the answer returns as a notification";
        if (r === "task")
            return "hand it to Claude — a wish becomes a PR, a task an artifact";
        if (r === "save")
            return "save this workspace as the '" + saveName + "' context";
        if (r === "resume")
            return "resume '" + resumeName + "' — reassemble its windows on a named workspace";
        return "launch " + (appMatch ? appMatch.name : "app");
    }
    function routeVerb(r) {
        if (r === "cmd")
            return "run";
        if (r === "ask")
            return "ask";
        if (r === "task")
            return "send";
        if (r === "save")
            return "save";
        if (r === "resume")
            return "resume";
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
        } else if (r === "save") {
            // Snapshot the current workspace into a named context. Deterministic,
            // no model call — dismiss like the app/$cmd routes; the CLI toasts.
            if (saveName === "")
                return;
            Quickshell.execDetached(["claudeos-context", "save", saveName]);
            reset();
        } else if (r === "resume") {
            // Reassemble a saved context onto its named workspace. Deterministic
            // window action (hyprctl), so it also just dismisses the overlay.
            if (resumeSlug === "")
                return;
            Quickshell.execDetached(["claudeos-context", "restore", resumeSlug]);
            reset();
        } else {
            // task → the intent router (Phase 2b). A real sentence that matched
            // no deterministic route hands off to claudeos-intent, which spends
            // one haiku call to decide wish (→ a PR) vs task (→ an artifact) —
            // or, if it's really an app/cmd/ask the QML pass missed, dispatches
            // that. An unroutable intent fails open into an interactive Claude.
            Quickshell.execDetached(["claudeos-intent", t]);
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
                        text: root.sent ? (root.route === "ask" ? "asking Claude…" : "routing…") : "intent"
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
                            text: "app, $command, a question?, or a task"
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
