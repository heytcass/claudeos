// Overview.qml — every occupied workspace as a live miniature, in one row.
// SUPER+Tab or a four-finger swipe up (Hyprland: `quickshell:overview`).
// Each tile is its workspace's monitor scaled down, with every window drawn at
// its real position as a live ScreencopyView of that toplevel — capture runs
// only while the overview is open. One trailing empty tile is the drop target
// for "put this on a fresh workspace".
//
//   click a window      → focus it (switching workspace) and close
//   click a tile        → go to that workspace and close
//   drag a window       → move it to the tile it's dropped on, silently
//   ← → / Return / Esc  → pick a tile / go there / dismiss
//
// Geometry comes from the raw hyprctl IPC payloads (`at`/`size` on clients),
// which the typed objects don't surface — so opening refreshes them first.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root
    property bool shown: false
    // Keyboard selection: index into `tiles`.
    property int selected: 0

    GlobalShortcut {
        appid: "quickshell"
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: root.shown ? root.close() : root.open()
    }

    function open() {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        root.shown = true;
        const fid = Hyprland.focusedWorkspace?.id;
        const i = root.tiles.findIndex(t => t.id === fid);
        root.selected = i < 0 ? 0 : i;
    }
    function close() {
        root.shown = false;
    }

    // The client address with its 0x prefix — HyprlandToplevel.address has
    // been seen both with and without it (see Workspaces.qml's urgent match).
    function addr(t) {
        const a = t.address ?? "";
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function focusWindow(t) {
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + addr(t) + "\" })");
        close();
    }
    function focusWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        close();
    }
    // follow = false: the window moves, your focus stays put in the overview.
    function moveWindow(t, id) {
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + id + ", window = \"address:" + addr(t) + "\", follow = false })");
        // The move event updates `workspace` on the toplevel, but `at` only
        // lands in lastIpcObject on a refresh — re-pull so it redraws in place.
        refreshLater.restart();
    }
    Timer {
        id: refreshLater
        interval: Motion.quick
        onTriggered: Hyprland.refreshToplevels()
    }

    // Tiles: occupied regular workspaces (plus the focused one even if it's
    // empty), sorted by id, then the lowest unused id as a blank drop target.
    // Each entry is { id, ws } — ws is null for the blank.
    readonly property var tiles: {
        const all = (Hyprland.workspaces?.values ?? []).filter(w => w.id > 0);
        const tops = Hyprland.toplevels?.values ?? [];
        const fid = Hyprland.focusedWorkspace?.id;
        const used = all.filter(w => w.id === fid || tops.some(t => t.workspace?.id === w.id)).sort((a, b) => a.id - b.id).map(w => ({
                    id: w.id,
                    ws: w
                }));
        var free = 1;
        while (all.some(w => w.id === free))
            free++;
        return used.concat([
            {
                id: free,
                ws: null
            }
        ]);
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
            keys.forceActiveFocus()

        // The monitor the overview opened on sets the tile aspect ratio for
        // the blank tile; real tiles use their own workspace's monitor.
        readonly property var mon: Hyprland.focusedMonitor

        // Tile width: a fifth of the screen at most, shrinking to fit a crowd.
        readonly property real tileW: Math.min(width * 0.18, (width - 2 * Theme.edgeGap * 4 - (root.tiles.length - 1) * Theme.gap * 3) / Math.max(1, root.tiles.length))

        // dim backdrop — click anywhere off a tile to dismiss
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onLeftPressed: root.selected = Math.max(0, root.selected - 1)
            Keys.onRightPressed: root.selected = Math.min(root.tiles.length - 1, root.selected + 1)
            Keys.onReturnPressed: root.focusWorkspace(root.tiles[root.selected].id)
            Keys.onTabPressed: root.selected = (root.selected + 1) % root.tiles.length
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.gap * 3

            // Arrive with a small overshoot, like the island's cards.
            opacity: win.visible ? 1 : 0
            scale: win.visible ? 1 : 0.94
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.standard
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Motion.emphasis
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveEmphasized
                }
            }

            Repeater {
                model: root.tiles

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property var ws: modelData.ws
                    readonly property var mon: ws?.monitor ?? win.mon
                    // Logical monitor size: client `at`/`size` are in layout
                    // (scaled) coordinates, monitor width/height in pixels.
                    readonly property real monW: (mon?.width ?? 1920) / (mon?.scale ?? 1)
                    readonly property real monH: (mon?.height ?? 1080) / (mon?.scale ?? 1)
                    readonly property real k: win.tileW / monW
                    readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData.id
                    readonly property bool picked: root.selected === index

                    width: win.tileW
                    height: monH * k + label.height + 8
                    // Lift the tile a dragged window is leaving above its
                    // siblings, so the thumbnail isn't drawn under them.
                    z: dragging ? 10 : 0
                    property bool dragging: false

                    Rectangle {
                        id: screen
                        width: parent.width
                        height: tile.monH * tile.k
                        radius: Theme.radius
                        clip: !tile.dragging
                        color: Theme.surfaceGlass
                        border.width: drop.containsDrag || tile.picked ? 2 : 1
                        border.color: drop.containsDrag ? Theme.accentAlt : tile.focused ? Theme.accent : tile.picked ? Theme.subtext : Theme.surface
                        Behavior on border.color {
                            ColorAnimation {
                                duration: Motion.quick
                            }
                        }

                        // Blank tile: a quiet plus where a new workspace would go.
                        Text {
                            visible: !tile.ws
                            anchors.centerIn: parent
                            text: "+"
                            color: drop.containsDrag ? Theme.accentAlt : Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: screen.height * 0.35
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selected = tile.index
                            onClicked: root.focusWorkspace(tile.modelData.id)
                        }

                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["window"]
                            onDropped: drag => {
                                const t = drag.source.toplevel;
                                if (t.workspace?.id !== tile.modelData.id)
                                    root.moveWindow(t, tile.modelData.id);
                            }
                        }

                        Repeater {
                            // Tiled first so floating windows draw on top.
                            model: (tile.ws?.toplevels?.values ?? []).slice().sort((a, b) => (a.lastIpcObject?.floating ? 1 : 0) - (b.lastIpcObject?.floating ? 1 : 0))

                            delegate: Item {
                                id: thumb
                                required property var modelData
                                readonly property var toplevel: modelData
                                readonly property var ipc: modelData.lastIpcObject ?? {}
                                readonly property real homeX: ((ipc.at?.[0] ?? 0) - (tile.mon?.x ?? 0)) * tile.k
                                readonly property real homeY: ((ipc.at?.[1] ?? 0) - (tile.mon?.y ?? 0)) * tile.k
                                readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")

                                x: homeX
                                y: homeY
                                width: Math.max(8, (ipc.size?.[0] ?? 0) * tile.k)
                                height: Math.max(8, (ipc.size?.[1] ?? 0) * tile.k)
                                z: grab.drag.active ? 100 : 0
                                scale: grab.drag.active ? 1.06 : grab.containsMouse ? 1.03 : 1
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Motion.quick
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Motion.curveStandard
                                    }
                                }

                                Drag.active: grab.drag.active
                                Drag.keys: ["window"]
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius / 2
                                    color: Theme.bgAlt
                                    border.width: grab.containsMouse || grab.drag.active ? 2 : 0
                                    border.color: Theme.accent
                                    clip: true

                                    ScreencopyView {
                                        id: view
                                        anchors.fill: parent
                                        anchors.margins: parent.border.width
                                        captureSource: root.shown ? thumb.toplevel.wayland : null
                                        live: root.shown
                                    }

                                    // App icon: the whole face until the first
                                    // frame lands, then a small corner badge.
                                    // Plain x/y rather than toggled anchors:
                                    // setting an anchor back to `undefined`
                                    // doesn't release it, so the badge stuck
                                    // in the centre.
                                    IconImage {
                                        readonly property real big: Math.min(parent.width, parent.height) * 0.4
                                        implicitSize: view.hasContent ? Math.min(20, big) : big
                                        x: view.hasContent ? parent.width - width - 4 : (parent.width - width) / 2
                                        y: view.hasContent ? parent.height - height - 4 : (parent.height - height) / 2
                                        source: thumb.entry ? Quickshell.iconPath(thumb.entry.icon, true) : ""
                                        visible: source !== ""
                                    }
                                }

                                MouseArea {
                                    id: grab
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    drag.target: thumb
                                    // A click shouldn't become a 1px drag.
                                    drag.threshold: 6
                                    onPressed: tile.dragging = true
                                    onReleased: {
                                        if (drag.active)
                                            thumb.Drag.drop();
                                        tile.dragging = false;
                                        // Snap home; a successful move re-homes
                                        // the thumbnail in its new tile anyway.
                                        thumb.x = Qt.binding(() => thumb.homeX);
                                        thumb.y = Qt.binding(() => thumb.homeY);
                                    }
                                    onClicked: root.focusWindow(thumb.toplevel)
                                }
                            }
                        }
                    }

                    Text {
                        id: label
                        anchors.top: screen.bottom
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.ws ? (tile.ws.name || tile.modelData.id) : "new"
                        color: tile.focused ? Theme.accent : Theme.subtext
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.bold: tile.focused
                    }
                }
            }
        }
    }
}
