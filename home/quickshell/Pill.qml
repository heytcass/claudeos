// Pill.qml — a rounded floating island that wraps a cluster of widgets.
// The bar is no longer one strip: left/right clusters each live in one of these
// pills, echoing the center Island's chrome (surface fill, full radius, faint
// muted border, hover-lighten) so the three read as a family of islands with
// wallpaper showing through the gaps between them.
import QtQuick

Rectangle {
    id: pill

    // Children declared inside a Pill land in `holder` (default property), so
    // callers just drop a RowLayout in and the pill sizes to it.
    default property alias content: holder.data

    // Horizontal breathing room between the pill edge and its content.
    property real padH: 12

    // Staggered entrance: each pill pops into place a beat after the last, so
    // the three islands read as *placed in sequence* rather than drawn at once.
    property int entranceDelay: 0
    opacity: 0
    scale: 0.92
    Component.onCompleted: entrance.start()
    SequentialAnimation {
        id: entrance
        PauseAnimation {
            duration: pill.entranceDelay
        }
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "opacity"
                to: 1
                duration: 320
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pill
                property: "scale"
                to: 1
                duration: 460
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
    }

    implicitHeight: Theme.barHeight - 6
    implicitWidth: holder.childrenRect.width + padH * 2
    radius: height / 2
    color: hover.hovered ? Qt.lighter(Theme.surface, 1.15) : Theme.surface
    border.width: 1
    border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.25)

    // childrenRect drives sizing; the content sits at 0,0 (no anchor → no loop)
    // and `holder` is what we center inside the pill.
    Item {
        id: holder
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    HoverHandler {
        id: hover
    }
}
