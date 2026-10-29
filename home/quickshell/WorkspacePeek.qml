// WorkspacePeek.qml — hover a bar workspace pill and this drops down under it:
// that workspace's monitor in miniature, every window a live WindowThumb at
// its real position (the Overview's tile, alone). Look without switching.
// Owned by Workspaces.qml, which moves `anchorItem`/`workspace` as the pointer
// crosses pills; capture runs only while it's open.
//
// A non-grabbing PopupWindow: it's a tooltip, so it must never take focus or
// clicks away from the bar — and a grabbing xdg_popup would close the moment
// the pointer moved to the next pill.
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: popup
    property Item anchorItem
    // A HyprlandWorkspace, or null.
    property var workspace: null

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 10
    grabFocus: false
    color: "transparent"

    readonly property var mon: workspace?.monitor ?? Hyprland.focusedMonitor
    readonly property real monW: (mon?.width ?? 1920) / (mon?.scale ?? 1)
    readonly property real monH: (mon?.height ?? 1080) / (mon?.scale ?? 1)
    readonly property real k: (implicitWidth - 2 * pad) / monW
    readonly property int pad: 8

    implicitWidth: 300
    implicitHeight: Math.round(monH * k) + label.height + pad * 3

    // Re-pull client geometry each time it opens: `at`/`size` only refresh
    // in lastIpcObject on request.
    onVisibleChanged: if (visible)
        Hyprland.refreshToplevels()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius + 2
        color: Theme.bgGlass
        border.width: 1
        border.color: Theme.surface

        opacity: popup.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }

        Rectangle {
            id: screen
            x: popup.pad
            y: popup.pad
            width: parent.width - 2 * popup.pad
            height: Math.round(popup.monH * popup.k)
            radius: Theme.radius
            color: Theme.surfaceGlass
            clip: true

            Repeater {
                model: popup.visible ? (popup.workspace?.toplevels?.values ?? []).slice().sort((a, b) => (a.lastIpcObject?.floating ? 1 : 0) - (b.lastIpcObject?.floating ? 1 : 0)) : []

                delegate: WindowThumb {
                    required property var modelData
                    readonly property var ipc: modelData.lastIpcObject ?? {}
                    toplevel: modelData
                    active: popup.visible
                    badgeSize: 14
                    x: ((ipc.at?.[0] ?? 0) - (popup.mon?.x ?? 0)) * popup.k
                    y: ((ipc.at?.[1] ?? 0) - (popup.mon?.y ?? 0)) * popup.k
                    width: Math.max(6, (ipc.size?.[0] ?? 0) * popup.k)
                    height: Math.max(6, (ipc.size?.[1] ?? 0) * popup.k)
                }
            }
        }

        Text {
            id: label
            anchors.top: screen.bottom
            anchors.topMargin: popup.pad
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property int count: popup.workspace?.toplevels?.values?.length ?? 0
            text: "workspace " + (popup.workspace?.name ?? "") + " · " + count + (count === 1 ? " window" : " windows")
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
    }
}
