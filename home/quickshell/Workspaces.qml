// Workspaces.qml — Hyprland workspace pills. The focused one widens, goes
// terracotta, springs on switch, and sits in a soft accent glow; occupied
// pills sit warmer than empty ones. Click to switch, scroll anywhere on the
// row to cycle, and a pill breathes urgent-red when a window on it demands
// attention (until that workspace is visited).
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
    WheelHandler {
        onWheel: event => Hyprland.dispatch("workspace " + (event.angleDelta.y > 0 ? "e-1" : "e+1"))
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
                    duration: 90
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: pillRect
                    property: "scale"
                    to: 1
                    duration: 240
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
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
                        duration: 260
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
                        duration: 650
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.35
                        duration: 650
                        easing.type: Easing.InOutSine
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
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 220
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
                    onClicked: Hyprland.dispatch("workspace " + cell.modelData.id)
                }
            }
        }
    }
}
