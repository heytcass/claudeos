// HealthWidget.qml — the bar's conscience. Exists only when a claudeos-* /
// claude-* systemd unit (user or system) is in the failed state: a small
// warn-coloured dot breathes until the failure clears. Click lists the failed
// units. The probe itself lives in the Health singleton (one poll for every
// monitor, and the island's NeedsYou queue reads the same list).
import QtQuick
import Quickshell

Item {
    id: root
    // Holds the right pill open while the popup is up (Bar.qml).
    readonly property bool popupOpen: popup.visible
    readonly property var failedList: Health.failedList

    visible: Health.failed !== ""
    implicitWidth: visible ? dot.width + 8 : 0
    implicitHeight: Theme.barHeight - 8

    // The island's queue asks for the list; only the focused monitor answers,
    // so one popup opens, under the user's eyes.
    Connections {
        target: Health
        function onPopupRequested() {
            if (root.visible && BarFocus.isFocused(QsWindow.window))
                popup.visible = true;
        }
    }

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: Theme.warn
        SequentialAnimation on opacity {
            running: root.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.35
                duration: Motion.pulse
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveBreathe
            }
            NumberAnimation {
                to: 1
                duration: Motion.pulse
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveBreathe
            }
        }
    }

    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: col.implicitWidth + 28
        implicitHeight: col.implicitHeight + 20
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bgGlass
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "failed units"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Repeater {
                    model: root.failedList
                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: Theme.warn
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
