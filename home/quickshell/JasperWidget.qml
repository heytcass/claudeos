// JasperWidget.qml — Jasper's face in the bar: a compact insight pill showing
// the (elided) one-sentence insight; click reveals the full sentence in a
// popup. Hidden entirely when the lane has nothing to say — one thing, never a
// feed. Reads the Jasper singleton; every color comes from Theme.
import QtQuick
import Quickshell

Item {
    id: root
    visible: Jasper.text !== ""
    implicitWidth: label.width
    implicitHeight: Theme.barHeight

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Jasper.text
        color: Jasper.stale ? Theme.muted : Theme.subtext
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        maximumLineCount: 1
        // contentWidth is the natural text width (independent of `width`, so no
        // binding loop); cap it so a long insight elides instead of shoving the
        // rest of the bar around.
        width: Math.min(contentWidth, 320)
    }

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
                    text: Jasper.text
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
