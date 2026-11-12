// Summon.qml — one key, one surface: launch an app or run any Claude action.
// SUPER+Space opens a centered capsule (Hyprland: lib/keybindings.nix binds
// `<Super>space` to the `quickshell:summon` global; `qs ipc call summon
// toggle` reaches it too). It grew out of the intent line and replaced fuzzel
// (2026-11): thirteen separate Claude shortcuts became rows in one list.
//
//   opened empty → the Claude actions, most used in the last 30 days first
//                  (Usage.qml / claudeos-usage), else lib/keybindings.nix
//                  order (via the generated Keybinds.actions)
//   typing       → actions and apps filtered together into one ranked list,
//                  with "Go to: <label>" rows for workspaces whose purpose
//                  label (WorkspaceNames.qml) matches, ranked after exact
//                  app/action matches; plus the deterministic routes as rows
//                  of their own:
//     $command    → run it in a terminal
//     question?   → claude-ask-desktop (the answer returns as a notification)
//     save as <n> → snapshot this workspace as a task context
//     resume <n>  → reassemble a saved context onto its named workspace
//     otherwise   → the intent router (claudeos-intent): one haiku call picks
//                   wish (→ a reviewed PR) vs task (→ a reviewable artifact)
//
// ZERO model calls for apps, actions and commands — every row is classified in
// plain JS, and the top row (the predicted route) is visible before Enter.
// Up/Down, Tab/Shift+Tab or Ctrl+N/P move the selection (choosing another row
// IS rerouting — the old Tab ring became the list); Enter runs it; Esc or
// click-away dismisses. An action with a `prompt` (Ask) turns the input into
// that action's text field; Esc or Backspace on empty leaves it.
//
// Actions backed by a quickshell global call the owning surface's code path
// directly (runGlobal) instead of round-tripping through Hyprland. Actions
// marked `capture` close the summon and wait out its fade first, so the
// summon is never in the screenshot. Carries the island's agent-glow language
// (breathing accent, soft halo) and, for the async routes (ask / task), the
// genie exit into the island.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root
    property bool shown: false
    property bool sent: false
    // The action whose text the input is collecting (an entry with `prompt`),
    // or null for the normal list.
    property var mode: null
    property int selected: 0
    // Last pointer position (window coords) that moved the selection.
    property point lastHover: Qt.point(-1, -1)

    // Surfaces the global-backed actions drive (wired in shell.qml).
    property var wish: null
    property var regionShot: null

    readonly property int maxRows: 7

    function open() {
        root.sent = false;
        root.mode = null;
        root.selected = 0;
        root.lastHover = Qt.point(-1, -1);
        input.text = "";
        root.shown = true;
        Usage.refresh();              // re-rank the empty state by recent use
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "summon"
        description: "Summon — launch an app or run any Claude action"
        onPressed: root.shown ? root.reset() : root.open()
    }

    IpcHandler {
        target: "summon"
        function toggle(): void {
            root.shown ? root.reset() : root.open();
        }
    }

    // ---- the action registry (generated from lib/keybindings.nix) ----
    // `?? []` keeps a preview built on an older deployed Keybinds.qml loading:
    // the list is then apps + routes only (qml-preview --build has the real one).
    readonly property var registry: Keybinds.actions ?? []

    // Point at it only means something while an agent has armed a pick.
    function available(a) {
        if (a.global === "quickshell:pick")
            return !!(root.regionShot && root.regionShot.pickArmed);
        return true;
    }
    readonly property var actions: registry.filter(a => available(a))
    // The empty state's order: most used over the last 30 days first
    // (claudeos-usage counts, read when the summon opens); ties and no data
    // keep registry order.
    readonly property var byUse: {
        const c = Usage.counts;
        return root.actions.map((a, i) => ({
                    a: a,
                    i: i,
                    n: c[a.id] || 0
                })).sort((x, y) => (y.n - x.n) || (x.i - y.i)).map(x => x.a);
    }

    // ---- deterministic classification (pure JS, no model call ever) ----

    readonly property string qt: input.text.trim()

    function words(s) {
        return (s || "").toLowerCase().split(/[\s._\-]+/).filter(Boolean);
    }

    // Desktop entries matching the text, ranked best-first:
    //   exact name/id  >  name prefix  >  name word prefix  >  id prefix / word
    //   >  keyword / generic-name word  >  loose substring
    // Interior words matter: "chrome" must find "Google Chrome", "code" →
    // "Visual Studio Code". Still deliberately conservative — every tier is
    // anchored at a WORD boundary (or a substring of a single token), so a
    // real multi-word sentence matches nothing here and falls through to the
    // task route instead of launching something that merely shares letters.
    // The name you read outranks the id you don't: Chrome PWAs all get ids
    // like "chrome-<hash>-Default", which once let "chrome" launch a web app
    // (Home Assistant) ahead of Google Chrome itself.
    // Within a tier the shortest name is the most specific, so it comes first.
    // Returns [{e, tier}] with tier -1 (exact) … 4 (substring).
    function rankApps(text) {
        const q = text.trim().toLowerCase();
        if (q.length < 2)
            return [];
        const apps = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || e.noDisplay)
                continue;
            const n = (e.name || "").toLowerCase();
            const id = (e.id || "").toLowerCase();
            var tier = -2;
            if (n === q || id === q)
                tier = -1;                                 // exact
            else if (n.startsWith(q))
                tier = 0;
            else if (words(n).some(w => w.startsWith(q)))
                tier = 1;                                  // "chrome" → "Google Chrome"
            else if (id.startsWith(q) || words(id).some(w => w.startsWith(q)))
                tier = 2;                                  // "nautilus" → "Files"
            else if ((e.keywords || []).concat([e.genericName || ""]).some(k => words(k).some(w => w.startsWith(q))))
                tier = 3;                                  // "browser" → generic name
            else if (n.includes(q))
                tier = 4;
            if (tier > -2)
                out.push({
                    e: e,
                    tier: tier,
                    len: n.length
                });
        }
        return out.sort((a, b) => (a.tier - b.tier) || (a.len - b.len));
    }

    // Actions matching the text, on the same tier scale as apps so the two
    // lists merge honestly: exact name/keyword · name prefix · name word ·
    // keyword (prefix of it or of one of its words) · loose substring.
    function rankActions(text) {
        const q = text.trim().toLowerCase();
        if (q.length < 2)
            return [];
        var out = [];
        for (var i = 0; i < root.actions.length; i++) {
            const a = root.actions[i];
            const n = (a.name || "").toLowerCase();
            const kws = (a.keywords || []).map(k => k.toLowerCase());
            var tier = -2;
            if (n === q || kws.includes(q))
                tier = -1;
            else if (n.startsWith(q))
                tier = 0;
            else if (words(n).some(w => w.startsWith(q)))
                tier = 1;
            else if (kws.some(k => k.startsWith(q) || words(k).some(w => w.startsWith(q))))
                tier = 3;
            else if (n.includes(q))
                tier = 4;
            if (tier > -2)
                out.push({
                    a: a,
                    tier: tier,
                    order: i
                });
        }
        return out.sort((x, y) => (x.tier - y.tier) || (x.order - y.order));
    }

    // Workspaces whose purpose label matches, on the same tier scale but
    // never exact (-1): an exact app/action match always comes first, and an
    // app or action wins a tie (a label is often just the app's name). The
    // workspace you are on, and special workspaces, are left out.
    // Matches the full label, not the bar's elided one.
    function rankWorkspaces(text) {
        const q = text.trim().toLowerCase();
        if (q.length < 2)
            return [];
        const named = WorkspaceNames.labels;
        const wss = Hyprland.workspaces?.values ?? [];
        const here = Hyprland.focusedWorkspace?.id;
        var out = [];
        for (var i = 0; i < wss.length; i++) {
            const ws = wss[i];
            const e = named[ws.id];
            if (!e || ws.id < 0 || ws.id === here)
                continue;
            const n = e.full.toLowerCase();
            var tier = -2;
            if (n.startsWith(q))
                tier = 0;                                  // exact or prefix
            else if (words(n).some(w => w.startsWith(q)))
                tier = 1;
            else if (n.includes(q))
                tier = 4;
            if (tier > -2)
                out.push({
                    ws: ws,
                    e: e,
                    tier: tier
                });
        }
        return out.sort((x, y) => (x.tier - y.tier) || (x.ws.id - y.ws.id));
    }

    // ---- context routes: "save as <name>" / "resume <name>" ----
    // `save as` always matches (it NAMES a new context); `resume` matches only
    // when <name> resolves to a KNOWN context (Contexts.resolveResume), so
    // "resume normal life" stays a task rather than hijacking a sentence.
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

    // ---- rows ----
    // Every row: {kind: "action"|"app"|"route"|"prompt", title, sub, color,
    // glyph, mono (glyph is a Nerd Font icon), icon (app icon path), hint
    // (a direct key, if the action keeps one), plus the thing it runs.

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
        return Theme.accent;
    }
    function routeGlyph(r) {
        if (r === "cmd")
            return "❯";
        if (r === "ask")
            return "?";
        if (r === "task")
            return "✳";              // ✳ — the house asterisk; the machine takes it from here
        if (r === "save")
            return "⊕";              // ⊕ — capture the current workspace
        if (r === "resume")
            return "⟳";              // ⟳ — reassemble a saved one
        return "→";
    }
    function routeTitle(r) {
        if (r === "cmd")
            return "Run in a terminal";
        if (r === "ask")
            return "Ask Claude";
        if (r === "task")
            return "Hand it to Claude";
        if (r === "save")
            return "Save context '" + saveName + "'";
        if (r === "resume")
            return "Resume '" + resumeName + "'";
        return "";
    }
    function routeSub(r) {
        if (r === "cmd")
            return (qt.charAt(0) === "$" ? qt.slice(1).trim() : qt);
        if (r === "ask")
            return "the answer returns as a notification";
        if (r === "task")
            return "a wish becomes a PR, a task an artifact";
        if (r === "save")
            return "snapshot this workspace as a named context";
        if (r === "resume")
            return "reassemble its windows on a named workspace";
        return "";
    }
    function routeRow(r) {
        return {
            kind: "route",
            route: r,
            title: routeTitle(r),
            sub: routeSub(r),
            color: routeColor(r),
            glyph: routeGlyph(r),
            mono: false,
            icon: "",
            hint: ""
        };
    }
    function actionRow(a) {
        const g = Icons[a.icon];
        return {
            kind: "action",
            action: a,
            title: a.name,
            // "Screenshot analysis — Claude reads…" under a "Screenshot
            // analysis" title: drop the repeated lead-in
            sub: a.help.toLowerCase().startsWith(a.name.toLowerCase() + " — ") ? a.help.slice(a.name.length + 3) : a.help,
            color: Theme.base0E,          // the cheat sheet's Claude colour
            glyph: g ? g : "✳",
            mono: !!g,
            icon: "",
            hint: a.display || ""
        };
    }
    function appRow(e) {
        return {
            kind: "app",
            entry: e,
            title: e.name,
            sub: e.genericName || e.comment || "Application",
            color: Theme.accent,
            glyph: "→",
            mono: false,
            icon: Quickshell.iconPath(e.icon, true),
            hint: ""
        };
    }
    // w: a rankWorkspaces() match. The hint is the workspace's number.
    function workspaceRow(w) {
        const de = w.e.appId ? DesktopEntries.heuristicLookup(w.e.appId) : null;
        const mon = w.ws.monitor?.name ?? "";
        return {
            kind: "workspace",
            wsId: w.ws.id,
            title: "Go to: " + w.e.full,
            sub: "workspace " + w.ws.name + (mon !== "" ? " · " + mon : ""),
            color: Theme.base0D,          // blue — moving, not launching
            glyph: "→",
            mono: false,
            icon: de ? Quickshell.iconPath(de.icon, true) : "",
            hint: String(w.ws.name)
        };
    }

    readonly property var rows: {
        const t = qt;
        if (root.mode) {
            const m = root.mode;
            return [{
                    kind: "prompt",
                    title: t === "" ? m.prompt : t,
                    sub: t === "" ? m.help : m.name + " — Enter to send",
                    color: routeColor("ask"),
                    glyph: Icons[m.icon] || "?",
                    mono: !!Icons[m.icon],
                    icon: "",
                    hint: ""
                }];
        }
        if (t === "")
            return root.byUse.slice(0, root.maxRows).map(a => actionRow(a));
        if (t.charAt(0) === "$")
            return [routeRow("cmd")];

        var out = [];
        if (saveName !== "")
            out.push(routeRow("save"));
        if (resumeSlug !== "")
            out.push(routeRow("resume"));
        const trailingQ = t.charAt(t.length - 1) === "?";
        const question = trailingQ || isQuestion(t);
        // an explicit question wins over a name match; a leading "what" etc.
        // only after the matches (old intent-line precedence)
        if (trailingQ)
            out.push(routeRow("ask"));

        // actions, apps and workspaces, merged by tier; on a tie an action
        // beats an app beats a workspace (each list is already sorted)
        const acts = rankActions(t);
        const apps = rankApps(t);
        const wsm = rankWorkspaces(t);
        var merged = [];
        var ai = 0, pi = 0, wi = 0;
        while (ai < acts.length || pi < apps.length || wi < wsm.length) {
            const at = ai < acts.length ? acts[ai].tier : 99;
            const pt = pi < apps.length ? apps[pi].tier : 99;
            const wt = wi < wsm.length ? wsm[wi].tier : 99;
            if (at <= pt && at <= wt)
                merged.push(actionRow(acts[ai++].a));
            else if (pt <= wt)
                merged.push(appRow(apps[pi++].e));
            else
                merged.push(workspaceRow(wsm[wi++]));
        }
        // When something matched, the tail is just the task route (plus ask
        // for a question), leaving the room to the matches; when nothing did,
        // every route is offered.
        var tail = [];
        if (question && !trailingQ)
            tail.push("ask");
        tail.push("task");
        if (merged.length === 0) {
            if (!question)
                tail.push("ask");
            tail.push("cmd");
        }
        const room = Math.max(0, root.maxRows - out.length - tail.length);
        out = out.concat(merged.slice(0, room));
        return out.concat(tail.map(r => routeRow(r)));
    }

    readonly property int sel: Math.max(0, Math.min(root.selected, rows.length - 1))
    readonly property var current: rows.length ? rows[sel] : null
    readonly property color tint: current ? current.color : Theme.accent

    function move(d) {
        if (rows.length === 0)
            return;
        root.selected = (sel + d + rows.length) % rows.length;
    }
    function verb(row) {
        if (!row)
            return "run";
        if (row.kind === "app")
            return "launch";
        if (row.kind === "prompt")
            return "send";
        if (row.kind === "workspace")
            return "go";
        if (row.kind === "action")
            return row.action.prompt ? "ask" : "run";
        const r = row.route;
        return r === "cmd" ? "run" : r === "ask" ? "ask" : r === "task" ? "send" : r;
    }

    // ---- commit & dismiss ----

    function reset() {
        root.shown = false;
        root.sent = false;
        root.mode = null;
        root.selected = 0;
        input.text = "";
    }

    // Usage logging (Usage.qml → claudeos-usage): an action by its registry
    // id, a route by its kind, an app as just "app", a workspace jump as
    // just "route:workspace". Never the typed text, which app, or a label.
    function activate(row) {
        if (!row || root.sent)
            return;
        if (row.kind === "app") {
            row.entry.execute();          // launch detached; deterministic, instant
            Usage.log("app", "summon");
            reset();
        } else if (row.kind === "workspace") {
            Usage.log("route:workspace", "summon");
            reset();
            // The bar's own click path (Workspaces.qml): focusing a workspace
            // by id makes Hyprland move to the monitor it lives on. A tick
            // later, so the summon's layer has let go of the keyboard first.
            goWs.wsId = row.wsId;
            goWs.restart();
        } else if (row.kind === "action") {
            runAction(row.action);
        } else if (row.kind === "prompt") {
            const t = qt;
            if (t === "")
                return;
            // `command "$1"` — the text is one argv word, never re-parsed by sh.
            Quickshell.execDetached(["sh", "-c", root.mode.command + ' "$1"', "sh", t]);
            Usage.log(root.mode.id, "summon");
            root.sent = true;
            flight.start();
        } else {
            commitRoute(row.route);
        }
    }

    function runAction(a) {
        if (a.prompt) {
            // Ask & co.: the input becomes this action's text field.
            root.mode = a;
            root.selected = 0;
            input.text = "";
            return;                       // logged when the text is sent
        }
        // Calls the surface directly, not through its GlobalShortcut, so a
        // summon-launched circle/pick is counted once, here, as "summon".
        Usage.log(a.id, "summon");
        // Close first. A capture waits out the summon's fade (the layer's
        // layersOut is Motion.quick) so it is never in the frame; anything
        // else just yields a tick so the next surface gets keyboard focus.
        reset();
        launch.action = a;
        launch.interval = a.capture ? Motion.quick + Motion.instant : 0;
        launch.restart();
    }
    Timer {
        id: launch
        property var action: null
        onTriggered: root.execAction(action)
    }
    Timer {
        id: goWs
        property int wsId: 0
        interval: 0
        onTriggered: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
    }
    function execAction(a) {
        if (!a)
            return;
        if (a.global)
            runGlobal(a.global);
        else if (a.command)
            Quickshell.execDetached(["sh", "-c", a.command]);
    }
    // The same code paths the GlobalShortcuts run — no Hyprland round trip.
    function runGlobal(g) {
        if (g === "quickshell:wish" && root.wish)
            root.wish.open();
        else if (g === "quickshell:shelf")
            Shelf.popupOpen = true;
        else if (g === "quickshell:circle" && root.regionShot) {
            if (!root.regionShot.shown)
                root.regionShot.open(true);
        } else if (g === "quickshell:pick" && root.regionShot)
            root.regionShot.startPick("");
        else
            // Unknown global: fire it through the compositor (Lua form).
            Hyprland.dispatch("hl.dsp.global(" + JSON.stringify(g) + ")");
    }

    function commitRoute(r) {
        const t = qt;
        if (t === "")
            return;
        if (r === "cmd") {
            const cmd = t.charAt(0) === "$" ? t.slice(1).trim() : t;
            if (cmd === "")
                return;
            // Hold the terminal open after the command so its output is readable.
            Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", cmd + "; echo; echo '[press enter to close]'; read"]);
            Usage.log("route:cmd", "summon");
            reset();
        } else if (r === "ask") {
            // claude-ask-desktop takes an optional query arg; pass the sentence.
            Quickshell.execDetached(["claude-ask-desktop", t]);
            Usage.log("route:ask", "summon");
            root.sent = true;
            flight.start();               // the question flies into the island
        } else if (r === "save") {
            if (saveName === "")
                return;
            Quickshell.execDetached(["claudeos-context", "save", saveName]);
            Usage.log("route:save", "summon");
            reset();
        } else if (r === "resume") {
            if (resumeSlug === "")
                return;
            Quickshell.execDetached(["claudeos-context", "restore", resumeSlug]);
            Usage.log("route:resume", "summon");
            reset();
        } else {
            // task → the intent router. One haiku call decides wish (→ a PR)
            // vs task (→ an artifact) — or dispatches an app/cmd/ask the QML
            // pass missed. An unroutable intent fails open into Claude.
            Quickshell.execDetached(["claudeos-intent", t]);
            Usage.log("route:task", "summon");
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
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveAnticipate
        }
        NumberAnimation {
            target: card
            property: "anchors.topMargin"
            to: Theme.barHeight - card.height / 2
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveExit
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0.15
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveExit
        }
        onFinished: {
            root.reset();
            card.scale = 1;
            card.opacity = 1;
            card.anchors.topMargin = Qt.binding(() => win.height * 0.24);
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

        // The capsule, breathing like the island does while an agent works; its
        // accent follows the selected row's colour, so the route is legible
        // from the border alone. Top-anchored (not centred) so the input stays
        // put while the list below it grows and shrinks.
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: win.height * 0.24
            width: 600
            height: col.implicitHeight + 40
            radius: 20
            color: Theme.bgGlass
            border.width: 2
            border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.4 + 0.45 * glow)

            Behavior on border.color {
                ColorAnimation {
                    duration: Motion.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Motion.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }

            property real glow: 0
            SequentialAnimation on glow {
                running: root.shown
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: Motion.breathe
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveBreathe
                }
                NumberAnimation {
                    to: 0
                    duration: Motion.breathe
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveBreathe
                }
            }

            // Clicks on the capsule itself must not fall through to the
            // backdrop (which dismisses).
            MouseArea {
                anchors.fill: parent
                onClicked: input.forceActiveFocus()
            }

            // halo layers, painted below the capsule, tinted by the selection
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
                    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, modelData.alpha * (0.4 + 0.6 * card.glow))
                }
            }

            Column {
                id: col
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.width - 40
                spacing: 10

                // the input capsule; in prompt mode a chip names the action
                Rectangle {
                    visible: !root.sent
                    width: parent.width
                    height: 46
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

                    Rectangle {
                        id: modeChip
                        visible: root.mode !== null
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? chipText.implicitWidth + 18 : 0
                        height: 28
                        radius: 8
                        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.5)
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: root.mode ? root.mode.name : ""
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: root.mode ? modeChip.width + 18 : 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 3
                        clip: true

                        // typing re-predicts: the top row is the best guess again
                        onTextChanged: root.selected = 0
                        onAccepted: root.activate(root.current)
                        Keys.onPressed: function (event) {
                            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                            if (event.key === Qt.Key_Escape) {
                                if (root.mode) {
                                    root.mode = null;
                                    input.text = "";
                                } else
                                    root.reset();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) {
                                root.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) {
                                root.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backspace && input.text === "" && root.mode) {
                                root.mode = null;
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: root.mode ? root.mode.prompt : "an app, a workspace, a Claude action, $command, a question?, or a task"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 3
                        }
                    }
                }

                // the list — every row is something Enter can do, the selected
                // one is what it WILL do
                Column {
                    visible: !root.sent
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.rows
                        delegate: Rectangle {
                            id: rowItem
                            required property var modelData
                            required property int index
                            readonly property bool active: index === root.sel
                            width: parent.width
                            height: 46
                            radius: 10
                            color: active ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.14) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.45)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Motion.instant
                                }
                            }

                            // Hover selects only when the pointer really moved:
                            // rows re-render under a resting cursor as you
                            // type, and a synthetic hover there must not steal
                            // the selection Enter is about to run.
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: mouse => {
                                    const p = mapToItem(null, mouse.x, mouse.y);
                                    const last = root.lastHover;
                                    root.lastHover = Qt.point(p.x, p.y);
                                    // the first event after opening only
                                    // records where the pointer rests
                                    if (last.x < 0 || (p.x === last.x && p.y === last.y))
                                        return;
                                    root.selected = rowItem.index;
                                }
                                onClicked: root.activate(rowItem.modelData)
                            }

                            // leading icon: the app's own, else the glyph
                            Item {
                                id: lead
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26

                                Image {
                                    anchors.fill: parent
                                    visible: rowItem.modelData.icon !== ""
                                    source: rowItem.modelData.icon
                                    sourceSize.width: 26
                                    sourceSize.height: 26
                                    // Synchronous on purpose: image://icon/
                                    // must load on the main thread (see the
                                    // note in Workspaces.qml).
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: rowItem.modelData.icon === ""
                                    text: rowItem.modelData.glyph
                                    color: rowItem.modelData.color
                                    font.family: rowItem.modelData.mono ? Theme.fontMono : Theme.fontSans
                                    font.pixelSize: Theme.fontSize + 5
                                }
                            }

                            Column {
                                anchors.left: lead.right
                                anchors.leftMargin: 12
                                anchors.right: hintText.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: rowItem.modelData.title
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSize + 1
                                }
                                Text {
                                    width: parent.width
                                    text: rowItem.modelData.sub
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }

                            // right edge: the action's own key, so the summon
                            // teaches the three that have one; else Enter on
                            // the selected row
                            Text {
                                id: hintText
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowItem.modelData.hint !== "" ? rowItem.modelData.hint : (rowItem.active ? "↵" : "")
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }
                }

                // footer hint — the verb tracks the selection, so Enter never surprises
                Text {
                    visible: !root.sent
                    text: {
                        const more = (root.qt === "" && !root.mode && root.actions.length > root.maxRows) ? (root.actions.length - root.maxRows) + " more — type to find  ·  " : "";
                        return more + "↑↓ select  ·  Enter to " + root.verb(root.current) + "  ·  Esc to " + (root.mode ? "go back" : "dismiss");
                    }
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }

                // after an async send: what happens next
                Row {
                    visible: root.sent
                    spacing: 10
                    Text {
                        text: "✳"
                        color: root.tint
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.mode || (root.current && root.current.route === "ask")) ? "asking Claude — the answer will arrive as a notification" : "routing — watch the island, then the bar's ✻"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                    }
                }
            }
        }
    }
}
