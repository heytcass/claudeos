// JasperWidget.qml — Jasper's face in the bar: just the insight's mood emoji;
// click reveals the sentence in a popup. Hidden entirely when the lane has
// nothing to say — one thing, never a feed. Reads the Jasper singleton; every
// color comes from Theme.
//
// The lane's prompt guarantees "emoji, space, sentence", so split on the first
// space — never slice by character, multi-codepoint emoji (🌤️ = base +
// variation selector) would be cut in half.
//
// Root is the Text itself (self-sizing, like ActiveWindow.qml) — a wrapper Item
// with a hand-bound implicitWidth renders zero-width in a RowLayout, so don't.
import QtQuick
import Quickshell

Text {
    id: root

    // "emoji, space, sentence" → [emoji, sentence]; no space → treat it all as
    // the emoji and leave the popup body empty rather than duplicating.
    readonly property int splitAt: Jasper.text.indexOf(" ")
    readonly property string emoji: splitAt < 0 ? Jasper.text : Jasper.text.slice(0, splitAt)
    readonly property string sentence: splitAt < 0 ? "" : Jasper.text.slice(splitAt + 1)

    visible: text !== ""
    text: emoji
    opacity: Jasper.stale ? 0.5 : 1
    font.family: Theme.fontSans
    font.pixelSize: Theme.iconSize

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.margins.top: 6
        implicitWidth: 360
        implicitHeight: card.implicitHeight
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            id: card
            anchors.fill: parent
            implicitHeight: full.implicitHeight + 24
            color: Theme.bg
            radius: 14
            border.color: Theme.surface
            border.width: 1

            Column {
                id: full
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 6

                Text {
                    text: "JASPER"
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    font.letterSpacing: 1
                }
                Text {
                    width: parent.width
                    text: root.sentence !== "" ? root.sentence : Jasper.text
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 1
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: Jasper.stale
                    text: "· quiet for a while"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
