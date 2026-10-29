// Pin.qml — the pinned mini-window: a small live picture of one window, kept
// in a corner of the focused monitor on every workspace (a layer surface, so
// workspaces don't apply to it). SUPER+O pins the focused window (again to
// unpin); a right-click on a window in the Overview pins that one.
//
//   click        → focus the real window (switching workspace)
//   right-click  → move the pin to the next corner, clockwise
//   hover ×      → unpin
//
// It steps aside while its window is on screen anyway — there's no point
// showing you a picture of what you're looking at.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    GlobalShortcut {
        appid: "quickshell"
        name: "pin"
        description: "Pin the focused window as a live corner mini-window"
        onPressed: {
            Hyprland.refreshToplevels();
            PinState.toggle(Hyprland.activeToplevel);
        }
    }

    readonly property var toplevel: PinState.toplevel
    readonly property var ipc: toplevel?.lastIpcObject ?? {}
    // On screen already: its workspace is the active one on some monitor.
    readonly property bool onScreen: {
        const id = toplevel?.workspace?.id;
        return id !== undefined && (Hyprland.monitors?.values ?? []).some(m => m.activeWorkspace?.id === id);
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
        visible: root.toplevel !== null && !root.onScreen
        color: "transparent"
        exclusiveZone: 0
        // Clear of the bar on top-corner pins.
        WlrLayershell.layer: WlrLayer.Overlay

        readonly property bool bottom: PinState.corner < 2
        readonly property bool right: PinState.corner === 0 || PinState.corner === 3
        anchors {
            bottom: win.bottom
            top: !win.bottom
            right: win.right
            left: !win.right
        }
        margins {
            bottom: Theme.gap * 2
            top: Theme.barHeight + Theme.gap * 2
            right: Theme.gap * 2
            left: Theme.gap * 2
        }

        // A fifth of the screen wide; height follows the window's aspect.
        readonly property real aspect: (root.ipc.size?.[1] ?? 9) / Math.max(1, root.ipc.size?.[0] ?? 16)
        implicitWidth: Math.round((screen?.width ?? 1920) * 0.2)
        implicitHeight: Math.round(implicitWidth * Math.min(1.4, Math.max(0.3, aspect)))

        Item {
            id: frame
            anchors.fill: parent
            opacity: win.visible ? 1 : 0
            scale: win.visible ? 1 : 0.9
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

            WindowThumb {
                anchors.fill: parent
                toplevel: root.toplevel
                active: win.visible
                highlighted: mouse.containsMouse
                radius: Theme.radius
                badgeSize: 24
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton) {
                        PinState.corner = (PinState.corner + 1) % 4;
                        return;
                    }
                    Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + PinState.address + "\" })");
                }
            }

            // Unpin, shown on hover.
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: 22
                height: 22
                radius: 11
                color: unpin.containsMouse ? Theme.urgent : Theme.bgGlass
                border.width: 1
                border.color: Theme.surface
                opacity: mouse.containsMouse || unpin.containsMouse ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.quick
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: unpin.containsMouse ? Theme.bgAlt : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                }
                MouseArea {
                    id: unpin
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: PinState.address = ""
                }
            }
        }
    }
}
