// RegionShot.qml — the region screenshot (Print). The focused monitor is
// frozen first (grim to a file, shown full-screen), so menus and hover states
// survive; then you pick the part you want and say what it's for.
//
//   hover + click   → take the window (or bar island) under the pointer
//   drag            → a box; its edges snap to window, island and screen edges
//   C / Return      → copy the image
//   S               → save it to ~/Pictures
//   T               → grab the text in it (claude-grab-text, into the clipboard)
//   A               → ask Claude about it — type the question, Return to send
//   Esc             → back out (a selection first, then the whole thing)
//
// Circle to ask (Super+Shift+C) is the same selector in "circle" mode: once the
// box is chosen the question input opens straight away, and Return sends the
// crop to claudeos-circle-ask. The window then shrinks to a click-through
// overlay holding only a pending/answer/error card anchored beside the box.
//
// Point at it (`qs ipc call regionshot pick TOKEN PROMPT`) is the same
// selector driven by an agent, in two phases. First it is only *armed*: a
// small click-through pill at the bottom of every monitor shows the prompt
// and nothing is frozen, so the user can switch to whatever Claude is asking
// about. Then Super+Shift+P (quickshell:pick), or a click on the pill,
// freezes the monitor the user is on at that moment and opens the selector
// with the prompt in its hint; the first click or drag ends it — nothing is
// captured; the chosen window's identity (address, class, title) and
// geometry are written as JSON to $XDG_RUNTIME_DIR/claudeos-pick/TOKEN.json
// (Esc, or the pill's Cancel, writes {"cancelled":true}) for claudeos-pick,
// which is waiting on that file. IPC is synchronous, so a file handoff is the
// only way the bar can answer after the user has acted.
//
// The crop is cut in QML (grabToImage of a clipped copy of the frozen frame)
// at the monitor's real pixel density, so nothing outside the box ever leaves
// the shell. Shift+Print keeps the old instant full-screen grab.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool shown: false
    // "pick" → "drag" → "chosen" → "asking"
    property string mode: "pick"
    property string frozen: ""
    // The frame as a loadable URL — set only once grim has finished writing it
    // (an Image bound to a file still being written fails and never retries).
    property string frameUrl: ""
    // Selection, in the monitor's logical px.
    property rect sel: Qt.rect(0, 0, 0, 0)
    property point anchorPt: Qt.point(0, 0)
    property var mon: null
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // Circle to ask: ask Claude about the box, answer shown beside it.
    property bool circle: false
    // "waiting" → "answer" | "error": the card that replaces the frozen frame.
    readonly property bool replying: root.mode === "waiting" || root.mode === "answer" || root.mode === "error"
    property string answer: ""
    property string circleShot: ""
    // Point at it: non-empty while an agent is waiting for a pick.
    property string pickToken: ""
    property string pickPrompt: ""
    // Armed: the prompt pill is up, nothing frozen yet (see startPick).
    property bool pickArmed: false
    // Picking: the selector itself is open on behalf of the agent.
    readonly property bool picking: root.pickToken !== "" && !root.pickArmed
    // The shortcut that turns armed into picking, as the cheat sheet spells it.
    readonly property string pickKeys: (Keybinds.claude.find(k => k.global === "quickshell:pick")?.keys ?? ["Super", "Shift", "P"]).join("+")
    // The window a click took (its hyprctl object), null for a dragged box.
    property var pickedWin: null
    // The bar's islands on the frozen monitor, snapshotted with the frame
    // (BarRegions.qml) so they can be hovered, clicked and snapped to too.
    property var barRects: []

    IpcHandler {
        target: "regionshot"
        // Arm a pick for an agent. TOKEN names the answer file (a safe name
        // only — it becomes a path); PROMPT is shown to the user. A newer pick
        // supersedes an older one, whose CLI is told it was cancelled.
        function pick(token: string, prompt: string): void {
            if (!/^[A-Za-z0-9._-]{1,64}$/.test(token))
                return;
            if (root.pickToken !== "")
                root.finishPick(null, true);
            if (root.shown)
                root.close();
            root.pickToken = token;
            root.pickPrompt = prompt;
            root.pickArmed = true;
        }
        // Withdraw a pending pick: the waiting CLI timed out or was killed, so
        // nobody is listening — drop the token first so close() writes nothing.
        function cancel(token: string): void {
            if (root.pickToken !== token)
                return;
            const wasPicking = root.picking;
            root.pickToken = "";
            root.pickPrompt = "";
            root.pickArmed = false;
            if (wasPicking)
                root.close();
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "pick"
        description: "Point at it: freeze this monitor and pick what Claude asked about"
        onPressed: root.startPick("")
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "regionshot"
        description: "Freeze the screen and capture a region"
        onPressed: root.shown ? root.close() : root.open(false)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "circle"
        description: "Circle to ask: drag a region, ask Claude about it"
        onPressed: root.shown ? root.close() : root.open(true)
    }

    // Armed → picking: freeze MON (a monitor name; "" means the focused one)
    // and open the selector with the agent's prompt. No-op unless armed. The
    // pill is hidden first and the freeze waits a beat, or grim would catch
    // the pill itself in the frozen frame.
    function startPick(mon) {
        if (!root.pickArmed)
            return;
        root.pickArmed = false;
        if (root.shown)
            root.close();
        armGap.mon = mon;
        armGap.restart();
    }
    Timer {
        id: armGap
        interval: 80
        property string mon: ""
        onTriggered: root.open(false, mon)
    }
    function open(circle, monName) {
        root.circle = circle;
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        root.mon = (monName ? (Hyprland.monitors?.values ?? []).find(m => m.name === monName) : null) ?? Hyprland.focusedMonitor;
        root.barRects = BarRegions.rectsFor(root.mon?.name ?? "");
        root.frozen = root.runDir + "/claudeos-freeze-" + Date.now() + ".png";
        freeze.command = ["grim", "-o", root.mon?.name ?? "", root.frozen];
        freeze.running = true;
    }
    function close() {
        // Backing out of a pick tells the waiting CLI so, instead of leaving
        // it to its timeout.
        if (root.picking)
            root.finishPick(null, true);
        // Dismissing mid-wait kills the helper; its EXIT trap removes the crop.
        circleProc.running = false;
        if (root.circleShot !== "")
            Quickshell.execDetached(["rm", "-f", root.circleShot]);
        root.circleShot = "";
        root.answer = "";
        root.circle = false;
        root.shown = false;
        root.mode = "pick";
        root.sel = Qt.rect(0, 0, 0, 0);
        ask.text = "";
        if (root.frozen !== "")
            Quickshell.execDetached(["rm", "-f", root.frozen]);
        root.frozen = "";
        root.frameUrl = "";
    }

    Process {
        id: freeze
        onExited: code => {
            if (code === 0) {
                root.frameUrl = "file://" + root.frozen;
                root.mode = "pick";
                root.shown = true;
            } else
                root.frozen = "";
        }
    }

    // Snap candidates: the bar's islands, then the windows on the frozen
    // monitor's active workspace, topmost first (floating above tiled, then
    // most recently focused), each as {r: rect relative to the monitor, o: its
    // hyprctl object — null for a bar island, which is a box, not a window}.
    readonly property var windowInfos: {
        const m = root.mon;
        if (!m || !root.shown)
            return [];
        const wid = m.activeWorkspace?.id;
        const wins = (Hyprland.toplevels?.values ?? []).filter(t => t.workspace?.id === wid).map(t => t.lastIpcObject ?? {}).filter(o => o.at && o.size).sort((a, b) => ((b.floating ? 1 : 0) - (a.floating ? 1 : 0)) || ((a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99))).map(o => ({
                    r: Qt.rect(o.at[0] - m.x, o.at[1] - m.y, o.size[0], o.size[1]),
                    o: o
                }));
        // The bar sits on the Top layer, above tiled and floating windows —
        // but a true fullscreen window (bit 2 of `fullscreen`) covers it, and
        // then the islands aren't in the frame to pick.
        if (wins.some(w => ((w.o.fullscreen ?? 0) & 2) !== 0))
            return wins;
        return root.barRects.map(b => ({
                    r: b.r,
                    o: null
                })).concat(wins);
    }
    readonly property var windows: root.windowInfos.map(w => w.r)
    function windowInfoAt(x, y) {
        return root.windowInfos.find(w => x >= w.r.x && x < w.r.x + w.r.width && y >= w.r.y && y < w.r.y + w.r.height) ?? null;
    }
    function windowAt(x, y) {
        return root.windowInfoAt(x, y)?.r ?? null;
    }
    // Point at it: write the answer for the waiting CLI. `win` is the clicked
    // window's hyprctl object, or null for a plain box; `cancelled` is Esc. Written
    // via a temp file + rename so the reader never sees a partial file.
    function finishPick(win, cancelled) {
        const token = root.pickToken;
        root.pickToken = "";
        root.pickPrompt = "";
        root.pickArmed = false;
        const m = root.mon;
        const s = root.sel;
        const result = cancelled ? {
            cancelled: true
        } : {
            cancelled: false,
            monitor: m?.name ?? "",
            scale: m?.scale ?? 1,
            x: Math.round(s.x),
            y: Math.round(s.y),
            width: Math.round(s.width),
            height: Math.round(s.height),
            global: {
                x: Math.round(s.x + (m?.x ?? 0)),
                y: Math.round(s.y + (m?.y ?? 0)),
                width: Math.round(s.width),
                height: Math.round(s.height)
            },
            window: win === null ? null : {
                address: win.address ?? "",
                class: win.class ?? "",
                initialClass: win.initialClass ?? "",
                title: win.title ?? "",
                pid: win.pid ?? 0,
                workspace: win.workspace?.id ?? 0,
                floating: !!win.floating
            }
        };
        const path = root.runDir + "/claudeos-pick/" + token + ".json";
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\"", "sh", JSON.stringify(result), path]);
    }
    // Pull a coordinate onto the nearest window/screen edge within reach.
    readonly property real reach: 10
    function snap(v, horizontal, extent) {
        var best = v, dist = root.reach;
        const edges = [0, extent];
        for (const r of root.windows) {
            if (horizontal)
                edges.push(r.x, r.x + r.width);
            else
                edges.push(r.y, r.y + r.height);
        }
        for (const e of edges) {
            const d = Math.abs(e - v);
            if (d < dist) {
                dist = d;
                best = e;
            }
        }
        return best;
    }

    // Cut the selection out of the frozen frame and hand the file to `then`.
    function crop(then) {
        const out = root.runDir + "/claudeos-region-" + Date.now() + ".png";
        const px = (root.mon?.scale ?? 1);
        cut.grabToImage(result => {
            if (result.saveToFile(out))
                then(out);
            root.close();
        }, Qt.size(Math.round(root.sel.width * px), Math.round(root.sel.height * px)));
    }
    function copy() {
        crop(f => Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\" && rm -f \"$1\" && notify-send -a Screenshot 'Copied' 'Region in the clipboard'", "sh", f]));
    }
    function save() {
        crop(f => Quickshell.execDetached(["sh", "-c", "d=\"$HOME/Pictures\"; mkdir -p \"$d\"; t=\"$d/Screenshot_$(date +%Y%m%d-%H%M%S).png\"; mv \"$1\" \"$t\" && notify-send -a Screenshot 'Screenshot saved' \"$t\"", "sh", f]));
    }
    function grabText() {
        crop(f => Quickshell.execDetached(["claude-grab-text", f]));
    }
    function askClaude() {
        const q = ask.text.trim();
        crop(f => Quickshell.execDetached(["claude-ask-region", f, q]));
    }
    // A box is chosen. In circle mode the question input opens straight away.
    function chosen() {
        if (root.picking) {
            // A dragged box that lands exactly on a window is that window.
            const w = root.pickedWin ?? (root.windowInfos.find(i => Math.abs(i.r.x - root.sel.x) <= 1 && Math.abs(i.r.y - root.sel.y) <= 1 && Math.abs(i.r.width - root.sel.width) <= 1 && Math.abs(i.r.height - root.sel.height) <= 1)?.o ?? null);
            root.finishPick(w, false);
            root.close();
            return;
        }
        root.mode = "chosen";
        if (root.circle) {
            root.mode = "asking";
            ask.forceActiveFocus();
        }
    }
    // Circle to ask: cut the box into the (0700) runtime dir, hand it to the
    // helper, and show the pending card beside the box. The window stays up.
    function askCircle() {
        const q = ask.text.trim();
        const out = root.runDir + "/claudeos-circle-" + Date.now() + ".png";
        const px = (root.mon?.scale ?? 1);
        cut.grabToImage(result => {
            if (!result.saveToFile(out)) {
                root.answer = "Couldn't capture that region.";
                root.mode = "error";
                keys.forceActiveFocus();
                return;
            }
            root.circleShot = out;
            root.answer = "";
            root.mode = "waiting";
            keys.forceActiveFocus();
            circleProc.command = ["claudeos-circle-ask", out, q];
            circleProc.running = true;
        }, Qt.size(Math.round(root.sel.width * px), Math.round(root.sel.height * px)));
    }

    // The helper prints the answer, or a short readable error with exit 1.
    Process {
        id: circleProc
        stdout: StdioCollector {
            id: circleOut
        }
        onExited: code => {
            if (!root.shown || !root.circle)
                return;
            root.circleShot = "";
            const t = circleOut.text.trim();
            root.answer = t !== "" ? t : "Claude didn't answer.";
            root.mode = code === 0 ? "answer" : "error";
            keys.forceActiveFocus();
        }
    }

    PanelWindow {
        id: win
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === root.mon?.name) ?? null
        color: "transparent"
        exclusiveZone: -1
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.replying ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
        // While a reply card is up, only the card takes input; the rest of the screen is live.
        mask: root.replying ? replyMask : null
        Region {
            id: replyMask
            item: reply
        }
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        onVisibleChanged: if (visible)
            keys.forceActiveFocus()

        readonly property bool hasSel: root.sel.width > 2 && root.sel.height > 2
        // What the pointer would take on a click, while nothing is chosen.
        property var hoverRect: null
        readonly property rect shownRect: root.mode === "pick" && hoverRect ? hoverRect : root.sel

        // The crop source: a clipped copy of the frame under the selection.
        // Drawn beneath the full frame so it's never seen, only grabbed.
        Item {
            id: cut
            x: root.sel.x
            y: root.sel.y
            width: Math.max(1, root.sel.width)
            height: Math.max(1, root.sel.height)
            clip: true
            Image {
                x: -root.sel.x
                y: -root.sel.y
                width: win.width
                height: win.height
                source: root.frameUrl
                cache: false
            }
        }

        // The frozen frame.
        Image {
            id: frame
            visible: !root.replying
            anchors.fill: parent
            source: root.frameUrl
            cache: false
        }

        // Dim everything but the box: four panes around it.
        Item {
            anchors.fill: parent
            readonly property color shade: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, root.replying ? 0 : 0.5)
            readonly property rect r: win.shownRect
            readonly property bool any: r.width > 0 && r.height > 0
            Rectangle {
                color: parent.shade
                x: 0
                y: 0
                width: parent.width
                height: parent.any ? parent.r.y : parent.height
            }
            Rectangle {
                visible: parent.any
                color: parent.shade
                x: 0
                y: parent.r.y + parent.r.height
                width: parent.width
                height: parent.height - y
            }
            Rectangle {
                visible: parent.any
                color: parent.shade
                x: 0
                y: parent.r.y
                width: parent.r.x
                height: parent.r.height
            }
            Rectangle {
                visible: parent.any
                color: parent.shade
                x: parent.r.x + parent.r.width
                y: parent.r.y
                width: parent.width - x
                height: parent.r.height
            }
            Rectangle {
                visible: parent.any
                x: parent.r.x - 1
                y: parent.r.y - 1
                width: parent.r.width + 2
                height: parent.r.height + 2
                color: "transparent"
                border.width: 2
                border.color: root.mode === "pick" ? Theme.subtext : Theme.accent
                radius: 2
            }
            // Size readout, tucked above the box's top-left corner.
            Rectangle {
                visible: parent.any && root.mode !== "pick" && !root.replying
                x: parent.r.x
                y: Math.max(0, parent.r.y - height - 6)
                width: dims.implicitWidth + 12
                height: dims.implicitHeight + 6
                radius: 4
                color: Theme.bgGlass
                Text {
                    id: dims
                    anchors.centerIn: parent
                    text: Math.round(root.sel.width) + " × " + Math.round(root.sel.height)
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.mode === "pick" || root.mode === "drag" || root.mode === "chosen"
            cursorShape: Qt.CrossCursor
            onPositionChanged: event => {
                if (root.mode === "pick")
                    win.hoverRect = root.windowAt(event.x, event.y);
                else if (root.mode === "drag") {
                    const x = root.snap(event.x, true, win.width);
                    const y = root.snap(event.y, false, win.height);
                    root.sel = Qt.rect(Math.min(x, root.anchorPt.x), Math.min(y, root.anchorPt.y), Math.abs(x - root.anchorPt.x), Math.abs(y - root.anchorPt.y));
                }
            }
            onPressed: event => {
                // A fresh press starts over, even with a box already chosen.
                root.anchorPt = Qt.point(root.snap(event.x, true, win.width), root.snap(event.y, false, win.height));
                root.sel = Qt.rect(root.anchorPt.x, root.anchorPt.y, 0, 0);
                root.pickedWin = null;
                root.mode = "drag";
            }
            onReleased: event => {
                if (win.hasSel) {
                    root.chosen();
                    return;
                }
                // No real drag: a click takes the window under it.
                const w = root.windowInfoAt(event.x, event.y);
                if (w) {
                    root.sel = w.r;
                    root.pickedWin = w.o;
                    root.chosen();
                } else
                    root.mode = "pick";
            }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (root.mode === "asking")
                        root.mode = "chosen";
                    else if (root.mode === "chosen") {
                        root.mode = "pick";
                        root.sel = Qt.rect(0, 0, 0, 0);
                    } else
                        root.close();
                } else if (root.mode !== "chosen")
                    return;
                else if (event.key === Qt.Key_C || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.copy();
                else if (event.key === Qt.Key_S)
                    root.save();
                else if (event.key === Qt.Key_T)
                    root.grabText();
                else if (event.key === Qt.Key_A) {
                    root.mode = "asking";
                    ask.forceActiveFocus();
                } else
                    return;
                event.accepted = true;
            }
        }

        // Hint while picking.
        Rectangle {
            visible: root.mode === "pick"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.edgeGap * 6
            width: Math.min(win.width - 2 * Theme.edgeGap * 6, hintCol.implicitWidth + 36)
            height: hintCol.implicitHeight + 18
            radius: root.picking ? 12 : height / 2
            color: Theme.bgGlass
            border.width: 1
            border.color: root.picking ? Theme.accent : Theme.surface
            Column {
                id: hintCol
                anchors.centerIn: parent
                // Wide enough for the longer line, capped to the screen (not parent.width: that loops).
                width: Math.min(win.width - 2 * Theme.edgeGap * 6 - 36, Math.max(root.picking ? promptText.implicitWidth : 0, hint.implicitWidth))
                spacing: 4
                // Point at it: the agent's prompt, so the user knows what is wanted.
                Text {
                    id: promptText
                    visible: root.picking
                    width: parent.width
                    text: "Claude asks: " + (root.pickPrompt !== "" ? root.pickPrompt : "point at it")
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    id: hint
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "click a window or drag a box · Esc to cancel"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }
        }

        // Action bar: under the box, or above it when the box hugs the bottom.
        Rectangle {
            id: bar
            visible: root.mode === "chosen" || root.mode === "asking"
            readonly property bool below: root.sel.y + root.sel.height + height + 16 < win.height
            x: Math.max(8, Math.min(win.width - width - 8, root.sel.x + (root.sel.width - width) / 2))
            y: below ? root.sel.y + root.sel.height + 10 : Math.max(8, root.sel.y - height - 10)
            width: root.mode === "asking" ? 460 : actions.implicitWidth + 16
            height: 40
            radius: height / 2
            color: Theme.bgGlass
            border.width: 1
            border.color: Theme.surface
            Behavior on width {
                NumberAnimation {
                    duration: Motion.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }

            component Action: Rectangle {
                id: act
                property string key
                property string label
                property color tint: Theme.text
                signal activated
                implicitWidth: row.implicitWidth + 18
                height: 28
                radius: 14
                color: hov.containsMouse ? Theme.surface : "transparent"
                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: Theme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: act.key
                            color: act.tint
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    Text {
                        text: act.label
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: act.activated()
                }
            }

            Row {
                id: actions
                visible: root.mode === "chosen"
                anchors.centerIn: parent
                spacing: 2
                Action {
                    key: "C"
                    label: "Copy"
                    tint: Theme.accent
                    onActivated: root.copy()
                }
                Action {
                    key: "S"
                    label: "Save"
                    onActivated: root.save()
                }
                Action {
                    key: "T"
                    label: "Grab text"
                    onActivated: root.grabText()
                }
                Action {
                    key: "A"
                    label: "Ask Claude"
                    tint: Theme.base0E
                    onActivated: {
                        root.mode = "asking";
                        ask.forceActiveFocus();
                    }
                }
            }

            TextInput {
                id: ask
                visible: root.mode === "asking"
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: 13
                clip: true
                Keys.onReturnPressed: root.circle ? root.askCircle() : root.askClaude()
                Keys.onEnterPressed: root.circle ? root.askCircle() : root.askClaude()
                Keys.onEscapePressed: {
                    if (root.circle) {
                        root.close();
                        return;
                    }
                    root.mode = "chosen";
                    keys.forceActiveFocus();
                }
                Text {
                    visible: ask.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.circle ? "Ask about this… (Return with nothing for \"explain this\")" : "Ask Claude about this… (Return with nothing to just describe it)"
                    color: Theme.muted
                    font: ask.font
                }
            }
        }

        // Circle to ask: the pending / answer / error card, beside the box.
        // Right of it if there is room, else left, else below or above.
        Rectangle {
            id: reply
            visible: root.replying
            readonly property real pw: Math.min(400, win.width - 16)
            readonly property real gap: 12
            readonly property bool roomRight: root.sel.x + root.sel.width + gap + pw + 8 <= win.width
            readonly property bool roomLeft: root.sel.x - gap - pw >= 8
            readonly property bool roomBelow: root.sel.y + root.sel.height + gap + height + 8 <= win.height
            readonly property bool beside: roomRight || roomLeft
            width: pw
            height: Math.min(body.implicitHeight + head.height + 32, win.height * 0.6)
            x: beside ? (roomRight ? root.sel.x + root.sel.width + gap : root.sel.x - gap - pw) : Math.max(8, Math.min(win.width - pw - 8, root.sel.x))
            y: beside ? Math.max(8, Math.min(win.height - height - 8, root.sel.y)) : (roomBelow ? root.sel.y + root.sel.height + gap : Math.max(8, root.sel.y - height - gap))
            radius: 12
            color: Theme.bgGlass
            border.width: 1
            border.color: root.mode === "error" ? Theme.urgent : Theme.surface

            // Click anywhere on the card to dismiss (Copy sits above this).
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Row {
                id: head
                x: 14
                y: 12
                width: parent.width - 28
                height: 22
                spacing: 8
                Row {
                    id: dots
                    visible: root.mode === "waiting"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.accent
                            SequentialAnimation on opacity {
                                running: root.mode === "waiting"
                                loops: Animation.Infinite
                                PauseAnimation {
                                    duration: index * 160
                                }
                                NumberAnimation {
                                    to: 0.25
                                    duration: 400
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 400
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mode === "waiting" ? "Claude is looking…" : (root.mode === "error" ? "Couldn't answer" : "Claude")
                    color: root.mode === "error" ? Theme.urgent : Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            Rectangle {
                id: copyBtn
                visible: root.mode === "answer"
                property bool done: false
                onVisibleChanged: done = false
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 10
                width: copyLabel.implicitWidth + 18
                height: 24
                radius: 12
                color: copyHov.containsMouse ? Theme.surface : "transparent"
                Text {
                    id: copyLabel
                    anchors.centerIn: parent
                    text: copyBtn.done ? "Copied" : "Copy"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
                MouseArea {
                    id: copyHov
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", root.answer]);
                        copyBtn.done = true;
                    }
                }
            }
            Flickable {
                anchors.top: head.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 14
                contentHeight: body.implicitHeight
                clip: true
                interactive: contentHeight > height
                Text {
                    id: body
                    width: parent.width
                    text: root.mode === "waiting" ? "Reading the selected region and your question." : root.answer
                    wrapMode: Text.Wrap
                    color: root.mode === "waiting" ? Theme.subtext : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }
            }
        }
    }

    // Point at it, armed: a click-through pill at the bottom of every monitor
    // carrying the agent's prompt. Only the pill takes clicks (the mask), it
    // never takes keyboard focus, and the rest of the screen stays live, so the
    // user can walk to the right window before freezing anything. Clicking the
    // pill picks on that pill's monitor; the shortcut picks on the focused one.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: armWin
            required property ShellScreen modelData
            screen: modelData
            visible: root.pickArmed
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "claudeos-pick"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            mask: Region {
                item: armPill
            }

            Rectangle {
                id: armPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.edgeGap * 6
                width: Math.min(armWin.width - 2 * Theme.edgeGap * 6, armCol.implicitWidth + 36)
                height: armCol.implicitHeight + 18
                radius: 12
                color: Theme.bgGlass
                border.width: 1
                border.color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startPick(armWin.modelData.name)
                }

                Column {
                    id: armCol
                    anchors.centerIn: parent
                    width: Math.min(armWin.width - 2 * Theme.edgeGap * 6 - 36, Math.max(armPrompt.implicitWidth, armRow.implicitWidth))
                    spacing: 4
                    Text {
                        id: armPrompt
                        width: parent.width
                        text: "Claude asks: " + (root.pickPrompt !== "" ? root.pickPrompt : "point at it")
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Row {
                        id: armRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "go to it, then press " + root.pickKeys + " · or click here"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: armCancelText.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: armCancelHov.containsMouse ? Theme.surface : "transparent"
                            border.width: 1
                            border.color: Theme.surface
                            Text {
                                id: armCancelText
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Theme.urgent
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: armCancelHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Tells the waiting CLI it was cancelled (exit 1).
                                onClicked: root.finishPick(null, true)
                            }
                        }
                    }
                }
            }
        }
    }
}
