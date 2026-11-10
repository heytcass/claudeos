// ActiveWindow.qml — the focused window's title. The app icon lives on the
// focused workspace pill now (Workspaces.qml), so this is text only; it slides
// in on focus change instead of hard-snapping. Blank when nothing is focused.
import QtQuick
import Quickshell.Wayland

Item {
    id: root
    readonly property var win: ToplevelManager.activeToplevel
    readonly property string title: win?.title ?? ""
    readonly property string appId: win?.appId ?? ""

    visible: title !== ""
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // Focus-change transition: new window's title slides in from the left.
    // Keyed on appId (not title) so browser-tab retitles don't re-trigger it.
    onAppIdChanged: slide.restart()
    SequentialAnimation {
        id: slide
        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
            NumberAnimation {
                target: content
                property: "x"
                from: -7
                to: 0
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }
    }

    Row {
        id: content

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtext
            elide: Text.ElideRight
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            text: root.title
            width: Math.min(implicitWidth, 400)
        }
    }
}
