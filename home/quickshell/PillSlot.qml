// PillSlot.qml — one widget's place in the right pill, which is quiet by
// default (see Bar.qml): the slot is either open (the widget plus a trailing
// gap) or folded to zero width. Opening and closing ride the island's morph
// spring, so the pill grows and shrinks the way the centre Island does, and
// the widget fades and settles in rather than popping.
//
// The slot is never `visible: false`: a widget's own `visible` (Health,
// Cards, Media... hide themselves when idle) reads false under a hidden
// parent, and the slot needs that reading to know whether there is anything
// to show. A folded slot is disabled instead, so the clipped-away widget's
// handlers can't catch clicks or wheel events meant for its neighbours.
import QtQuick

Item {
    id: slot

    // Should the widget be on the pill right now? (Bar.qml decides: hovered,
    // a popup open, or the widget's state is abnormal.)
    property bool shown: false
    // Space after the widget, part of the slot so a folded slot leaves no
    // stray spacing behind (the RowLayout itself runs at spacing 0).
    property real gap: 6

    default property alias content: holder.data
    readonly property Item widget: holder.children.length > 0 ? holder.children[0] : null
    // The widget's own idea of its width; 0 when it has hidden itself.
    readonly property real natural: widget && widget.visible ? widget.implicitWidth : 0
    readonly property bool open: shown && natural > 0

    implicitHeight: Theme.barHeight - 8
    // The spring overshoots, so clamp: a negative width would be ignored by
    // the layout but still read as a glitch on the way closed.
    implicitWidth: Math.max(0, openWidth)
    property real openWidth: open ? natural + gap : 0
    Behavior on openWidth {
        SpringAnimation {
            spring: Motion.springMorph
            damping: Motion.dampingMorph
            mass: Motion.massMorph
        }
    }

    clip: true
    enabled: open

    Item {
        id: holder
        anchors.verticalCenter: parent.verticalCenter
        width: slot.natural
        height: slot.widget ? slot.widget.implicitHeight : 0
        opacity: slot.open ? 1 : 0
        scale: slot.open ? 1 : 0.8
        Behavior on opacity {
            NumberAnimation {
                duration: slot.open ? Motion.standard : Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: slot.open ? Motion.curveStandard : Motion.curveExit
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: slot.open ? Motion.emphasis : Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: slot.open ? Motion.curveEmphasized : Motion.curveExit
            }
        }
    }
}
