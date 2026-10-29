// RegionShot.qml — the region screenshot (Print). The focused monitor is
// frozen first (grim to a file, shown full-screen), so menus and hover states
// survive; then you pick the part you want and say what it's for.
//
//   hover + click   → take the window under the pointer
//   drag            → a box; its edges snap to window and screen edges
//   C / Return      → copy the image
//   S               → save it to ~/Pictures
//   T               → grab the text in it (claude-grab-text, into the clipboard)
//   A               → ask Claude about it — type the question, Return to send
//   Esc             → back out (a selection first, then the whole thing)
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

    GlobalShortcut {
        appid: "quickshell"
        name: "regionshot"
        description: "Freeze the screen and capture a region"
        onPressed: root.shown ? root.close() : root.open()
    }

    function open() {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        root.mon = Hyprland.focusedMonitor;
        root.frozen = root.runDir + "/claudeos-freeze-" + Date.now() + ".png";
        freeze.command = ["grim", "-o", root.mon?.name ?? "", root.frozen];
        freeze.running = true;
    }
    function close() {
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

    // Snap candidates: the windows on the frozen monitor's active workspace,
    // topmost first (floating above tiled, then most recently focused), as
    // rects relative to the monitor.
    readonly property var windows: {
        const m = root.mon;
        if (!m || !root.shown)
            return [];
        const wid = m.activeWorkspace?.id;
        return (Hyprland.toplevels?.values ?? []).filter(t => t.workspace?.id === wid).map(t => t.lastIpcObject ?? {}).filter(o => o.at && o.size).sort((a, b) => ((b.floating ? 1 : 0) - (a.floating ? 1 : 0)) || ((a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99))).map(o => Qt.rect(o.at[0] - m.x, o.at[1] - m.y, o.size[0], o.size[1]));
    }
    function windowAt(x, y) {
        return root.windows.find(r => x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height) ?? null;
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

    PanelWindow {
        id: win
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === root.mon?.name) ?? null
        color: "transparent"
        exclusiveZone: -1
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
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
            anchors.fill: parent
            source: root.frameUrl
            cache: false
        }

        // Dim everything but the box: four panes around it.
        Item {
            anchors.fill: parent
            readonly property color shade: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.5)
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
                visible: parent.any && root.mode !== "pick"
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
                root.mode = "drag";
            }
            onReleased: event => {
                if (win.hasSel) {
                    root.mode = "chosen";
                    return;
                }
                // No real drag: a click takes the window under it.
                const r = root.windowAt(event.x, event.y);
                if (r) {
                    root.sel = r;
                    root.mode = "chosen";
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
            width: hint.implicitWidth + 28
            height: hint.implicitHeight + 14
            radius: height / 2
            color: Theme.bgGlass
            border.width: 1
            border.color: Theme.surface
            Text {
                id: hint
                anchors.centerIn: parent
                text: "click a window or drag a box · Esc to cancel"
                color: Theme.subtext
                font.family: Theme.fontSans
                font.pixelSize: 13
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
                Keys.onReturnPressed: root.askClaude()
                Keys.onEnterPressed: root.askClaude()
                Keys.onEscapePressed: {
                    root.mode = "chosen";
                    keys.forceActiveFocus();
                }
                Text {
                    visible: ask.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ask Claude about this… (Return with nothing to just describe it)"
                    color: Theme.muted
                    font: ask.font
                }
            }
        }
    }
}
