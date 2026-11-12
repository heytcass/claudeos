// Workspaces.qml — Hyprland workspace pills as a map of where things live.
// Each pill shows its number and, when occupied, the app icon of the window on
// it (the workspace's last-focused window when there are several); empty
// workspaces, and apps whose icon doesn't resolve, show just the number. The
// focused one widens, goes terracotta, springs on switch, and sits in a soft
// accent glow; occupied pills sit warmer than empty ones, and their icons dim
// a touch so the focused one reads brightest. A workspace holding a Claude
// window wears a breathing accent ring while any Claude session is busy (the
// island's breath, focused output only). Click to switch, scroll anywhere on
// the row to cycle, and a pill breathes urgent-red when a window on it demands
// attention (until that workspace is visited; urgent outranks the Claude
// ring). Hover an occupied pill for a live peek at it (WorkspacePeek.qml).
// Each occupied workspace also has a short purpose label (WorkspaceNames.qml:
// its Claude session, project, or app): the focused pill wears it after the
// icon, the others unfold theirs on hover, on the island's morph spring.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    id: root
    spacing: 6

    // Workspace ids with an unserviced urgent window. Object-as-set; reassign
    // to retrigger bindings (in-place mutation doesn't notify).
    property var urgentIds: ({})

    // App ids / classes that mean "Claude is here". Extend this list.
    readonly property var claudeAppIds: ["com.anthropic.Claude"]
    function isClaude(t) {
        return root.claudeAppIds.indexOf(root.appIdOf(t)) !== -1;
    }
    // Wayland appId is live; the IPC class is the fallback (re-read on the
    // window events below).
    function appIdOf(t) {
        return t?.wayland?.appId || t?.lastIpcObject?.class || "";
    }
    // Existence-checked icon path for a toplevel ("" when none resolves).
    function iconFor(t) {
        const id = root.appIdOf(t);
        if (id === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(id);
        return entry ? Quickshell.iconPath(entry.icon, true) : "";
    }
    // Quickshell may hold addresses bare while IPC payloads carry "0x".
    function sameAddr(a, b) {
        if (!a || !b)
            return false;
        return String(a).replace(/^0x/, "") === String(b).replace(/^0x/, "");
    }

    // Last-focused window per workspace id, tracked live off the active
    // toplevel (no IPC round-trip). Each pill falls back to its workspace's
    // IPC `lastwindow`, then to its first window. Reassign to notify.
    property var lastFocused: ({})
    function noteFocus() {
        const t = Hyprland.activeToplevel;
        const wid = t?.workspace?.id;
        if (!t || wid === undefined || wid === null)
            return;
        const next = Object.assign({}, root.lastFocused);
        next[wid] = t.address;
        root.lastFocused = next;
    }
    Component.onCompleted: noteFocus()

    // Claude ring breath, by Island.qml's rules: one driver for the row, run
    // only on the focused output; off-focus rows hold a steady mid value.
    // Visuals read `glow`, never `pulse` (a stopped animation strands it).
    readonly property bool claudeBusy: Sessions.busy > 0
    readonly property bool onFocusedScreen: BarFocus.isFocused(QsWindow.window)
    readonly property bool claudePresent: (Hyprland.toplevels?.values ?? []).some(t => root.isClaude(t))
    property real pulse: 0
    readonly property real glow: root.onFocusedScreen ? root.pulse : 0.5
    SequentialAnimation on pulse {
        running: root.claudeBusy && root.claudePresent && root.onFocusedScreen
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

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.noteFocus();
        }
        function onRawEvent(event) {
            // Window topology changed: re-read IPC so `lastIpcObject.class`
            // and each workspace's window count / lastwindow stay current.
            // (movewindowv2 always fires alongside movewindow; one is enough.)
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindowv2") {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                return;
            }
            if (event.name !== "urgent")
                return;
            // event data is the window address; find its workspace.
            const addr = event.data.trim();
            const t = (Hyprland.toplevels?.values ?? []).find(t => t.address === addr || t.address === "0x" + addr);
            const wid = t?.workspace?.id;
            if (wid === undefined || wid === null)
                return;
            const next = Object.assign({}, root.urgentIds);
            next[wid] = true;
            root.urgentIds = next;
        }
    }

    // Wheel anywhere on the row steps through existing workspaces in pill
    // (screen) order — Hyprland's own "e+1" walks ids, which no longer match
    // what the row shows. Stops at either end.
    //
    // Lua config form, not the legacy string: Hyprland.dispatch wraps its
    // argument verbatim in hl.dispatch(...), so "workspace e+1" reaches Lua as
    // hl.dispatch(workspace e+1) and dies on a syntax error. Same casualty
    // class as the hyprctl dispatch dpms breakage (docs/known-issues.md).
    WheelHandler {
        onWheel: event => {
            const next = WorkspaceOrder.neighbour(Hyprland.focusedWorkspace?.id, event.angleDelta.y > 0 ? -1 : 1);
            if (next)
                Hyprland.dispatch("hl.dsp.focus({ workspace = " + next.id + " })");
        }
    }

    // Hover peek: rest on an unfocused, occupied pill for a beat and its
    // workspace drops down live (WorkspacePeek.qml). One popup for the row,
    // re-anchored as the pointer crosses pills; a short grace on leave so
    // sliding between neighbours doesn't flicker it shut.
    property Item peekItem: null
    property var peekWs: null
    function hoverPill(item, ws, inside) {
        if (inside && ws) {
            root.peekItem = item;
            root.peekWs = ws;
            peekClose.stop();
            if (peek.visible) {
                peek.anchor.updateAnchor();
            } else
                peekOpen.restart();
        } else if (root.peekItem === item || inside) {
            peekOpen.stop();
            peekClose.restart();
        }
    }
    Timer {
        id: peekOpen
        interval: Motion.standard
        onTriggered: peek.visible = root.peekWs !== null
    }
    Timer {
        id: peekClose
        interval: Motion.quick
        onTriggered: {
            peek.visible = false;
            root.peekItem = null;
            root.peekWs = null;
        }
    }
    WorkspacePeek {
        id: peek
        anchorItem: root.peekItem
        workspace: root.peekWs
        visible: false
    }

    // Screen order, numbered by position (WorkspaceOrder.qml), never by
    // Hyprland's id: laptop-left-of-external reads 1, 2 | 3, not 2 | 4.
    Repeater {
        model: WorkspaceOrder.ordered

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData.id
            // Window count comes from the raw hyprctl IPC payload — the typed
            // HyprlandWorkspace object doesn't surface it.
            readonly property bool occupied: (modelData.lastIpcObject?.windows ?? 0) > 0
            readonly property bool urgent: !focused && (root.urgentIds[modelData.id] ?? false)
            // The workspace's windows (live typed model), and the one whose
            // icon stands for it: last focused here, else IPC lastwindow,
            // else the first.
            readonly property var wins: modelData.toplevels?.values ?? []
            readonly property var lead: {
                const ws = cell.wins;
                if (ws.length === 0)
                    return null;
                const mine = root.lastFocused[modelData.id];
                const ipc = modelData.lastIpcObject?.lastwindow;
                return ws.find(t => root.sameAddr(t.address, mine)) ?? ws.find(t => root.sameAddr(t.address, ipc)) ?? ws[0];
            }
            readonly property string iconSource: root.iconFor(lead)
            // Claude lives here and a session is busy: breathing accent ring.
            readonly property bool claudeMarked: root.claudeBusy && !urgent && wins.some(t => root.isClaude(t))
            // Purpose label ("" = none: the pill stays number + icon). Shown
            // on the focused pill, and on any other while hovered. The text
            // is held while the slot folds, so it doesn't blank mid-fold.
            readonly property string label: WorkspaceNames.labels[modelData.id]?.label ?? ""
            readonly property bool showLabel: label !== "" && (focused || pillMouse.containsMouse)
            property string heldLabel: label
            onLabelChanged: if (label !== "")
                heldLabel = label

            implicitWidth: pillRect.implicitWidth
            implicitHeight: 20
            // The label unfolding under a peek moves the pill's centre:
            // keep the peek hung from it.
            onWidthChanged: if (root.peekItem === cell && peek.visible)
                peek.anchor.updateAnchor()

            // Bounce the focused pill when it becomes focused; visiting a
            // workspace services its urgency.
            onFocusedChanged: {
                if (!focused)
                    return;
                pop.restart();
                if (root.urgentIds[modelData.id]) {
                    const next = Object.assign({}, root.urgentIds);
                    delete next[modelData.id];
                    root.urgentIds = next;
                }
            }
            SequentialAnimation {
                id: pop
                NumberAnimation {
                    target: pillRect
                    property: "scale"
                    to: 1.18
                    duration: Motion.instant
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
                NumberAnimation {
                    target: pillRect
                    property: "scale"
                    to: 1
                    duration: Motion.standard
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveEmphasized
                }
            }

            // soft glow behind the focused (accent) or urgent (red) pill
            Rectangle {
                anchors.centerIn: pillRect
                width: pillRect.width + 10
                height: pillRect.height + 10
                radius: height / 2
                color: cell.urgent ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.26) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                opacity: cell.focused ? 1 : (cell.urgent ? urgentBreath.value : 0)
                scale: pillRect.scale
                Behavior on opacity {
                    enabled: !cell.urgent
                    NumberAnimation {
                        duration: Motion.standard
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveStandard
                    }
                }
            }
            // Breath driver for the urgent state (glow + pill share the beat).
            Item {
                id: urgentBreath
                property real value: 0
                SequentialAnimation on value {
                    running: cell.urgent
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 1
                        duration: Motion.pulse
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveBreathe
                    }
                    NumberAnimation {
                        to: 0.35
                        duration: Motion.pulse
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveBreathe
                    }
                }
            }

            Rectangle {
                id: pillRect
                anchors.centerIn: parent
                // Follows content: number, or number + icon. The floors keep
                // a bare number at the old 20/28 sizes. The label slot adds
                // its own (spring-animated) width on top, so the two motions
                // sum instead of one Behavior chasing the other.
                property real baseWidth: Math.max(cell.focused ? 28 : 20, content.implicitWidth + (cell.focused ? 14 : 12))
                implicitWidth: baseWidth + labelSlot.width
                width: implicitWidth
                height: 20
                radius: 10
                // Occupied-but-unfocused pills sit a shade warmer than empty
                // ones, so the eye can count where windows live. Urgent trumps.
                color: cell.focused ? Theme.accent : cell.urgent ? Theme.urgent : cell.occupied ? Qt.lighter(Theme.surface, 1.35) : Theme.surface

                Behavior on baseWidth {
                    NumberAnimation {
                        duration: Motion.quick
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveEmphasized
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Motion.quick
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveStandard
                    }
                }

                // number + icon (`content`, which sizes baseWidth), then the
                // label slot; centred as one so the padding stays even.
                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    Row {
                        id: content
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: WorkspaceOrder.numberOf(cell.modelData.id)
                            color: cell.focused || cell.urgent ? Theme.bgAlt : cell.occupied ? Theme.text : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                        // Full-colour app icon; dimmed off-focus so the focused
                        // pill's reads brightest. Hidden (no placeholder) when
                        // nothing resolves.
                        // On the focused pill the icon sits on a dark chip: an
                        // accent-coloured icon (Claude's own) would otherwise
                        // vanish into the accent fill.
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: cell.iconSource !== ""
                            width: cell.focused ? 18 : 14
                            height: width
                            radius: 6
                            color: cell.focused ? Theme.bgAlt : "transparent"

                            Image {
                                anchors.centerIn: parent
                                source: cell.iconSource
                                sourceSize.width: 14
                                sourceSize.height: 14
                                width: 14
                                height: 14
                                opacity: cell.focused ? 1 : 0.75
                                // Never `asynchronous` on an image://icon/ source:
                                // that moves QIcon theme loading onto Qt's pixmap
                                // reader thread, where it races the main thread's
                                // own icon loads (tray, WindowThumb) on the shared
                                // theme cache and segfaults the bar (2026-11-11).
                            }
                        }
                    }

                    // The purpose label, folded to zero width unless shown. Its
                    // width rides the island's morph spring (as PillSlot does);
                    // the leading 5px gap lives inside the slot so a folded slot
                    // leaves no stray spacing.
                    Item {
                        id: labelSlot
                        anchors.verticalCenter: parent.verticalCenter
                        property real openWidth: cell.showLabel ? labelText.implicitWidth + 5 : 0
                        Behavior on openWidth {
                            SpringAnimation {
                                spring: Motion.springMorph
                                damping: Motion.dampingMorph
                                mass: Motion.massMorph
                            }
                        }
                        // the spring overshoots: never a negative width
                        width: Math.max(0, openWidth)
                        height: 20
                        clip: true

                        Text {
                            id: labelText
                            x: 5
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.heldLabel
                            color: cell.focused || cell.urgent ? Theme.bgAlt : Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            opacity: cell.showLabel ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: cell.showLabel ? Motion.standard : Motion.quick
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: cell.showLabel ? Motion.curveStandard : Motion.curveExit
                                }
                            }
                        }
                    }
                }

                // Claude marker: a 1px accent ring just outside the pill (so
                // it still reads on the accent-filled focused pill). Its
                // opacity carries the shared breath — never its colour.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.accent
                    visible: cell.claudeMarked
                    opacity: 0.3 + 0.6 * root.glow
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    // No peek at the workspace you're on, or at an empty one.
                    onContainsMouseChanged: root.hoverPill(cell, cell.focused || !cell.occupied ? null : cell.modelData, containsMouse)
                    onClicked: {
                        root.hoverPill(cell, null, true);
                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.modelData.id + " })");
                    }
                }
            }
        }
    }
}
