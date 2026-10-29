// Workspaces.qml — Hyprland workspace pills. The focused one widens, goes
// terracotta, springs on switch, and sits in a soft accent glow; occupied
// pills sit warmer than empty ones. Click to switch, scroll anywhere on the
// row to cycle, and a pill breathes urgent-red when a window on it demands
// attention (until that workspace is visited). Hover an occupied pill for a
// live peek at it (WorkspacePeek.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    id: root
    spacing: 6

    // Workspace ids with an unserviced urgent window. Object-as-set; reassign
    // to retrigger bindings (in-place mutation doesn't notify).
    property var urgentIds: ({})

    Connections {
        target: Hyprland
        function onRawEvent(event) {
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

    // Wheel anywhere on the row cycles through existing workspaces.
    //
    // Lua config form, not the legacy string: Hyprland.dispatch wraps its
    // argument verbatim in hl.dispatch(...), so "workspace e+1" reaches Lua as
    // hl.dispatch(workspace e+1) and dies on a syntax error. Same casualty
    // class as the hyprctl dispatch dpms breakage (docs/known-issues.md).
    WheelHandler {
        onWheel: event => Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (event.angleDelta.y > 0 ? "e-1" : "e+1") + "\" })")
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

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData.id
            // Window count comes from the raw hyprctl IPC payload — the typed
            // HyprlandWorkspace object doesn't surface it.
            readonly property bool occupied: (modelData.lastIpcObject?.windows ?? 0) > 0
            readonly property bool urgent: !focused && (root.urgentIds[modelData.id] ?? false)

            implicitWidth: pillRect.implicitWidth
            implicitHeight: 20

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
                implicitWidth: cell.focused ? 28 : 20
                width: implicitWidth
                height: 20
                radius: 10
                // Occupied-but-unfocused pills sit a shade warmer than empty
                // ones, so the eye can count where windows live. Urgent trumps.
                color: cell.focused ? Theme.accent : cell.urgent ? Theme.urgent : cell.occupied ? Qt.lighter(Theme.surface, 1.35) : Theme.surface

                Behavior on implicitWidth {
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

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.name
                    color: cell.focused || cell.urgent ? Theme.bgAlt : cell.occupied ? Theme.text : Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                MouseArea {
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
