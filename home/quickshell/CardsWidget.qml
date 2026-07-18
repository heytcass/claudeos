// CardsWidget.qml — the bar glyph for generated surfaces (Phase 4). Exists only
// while at least one card is live (Cards.count > 0): a small stacked-cards mark
// drawn from two offset rounded rectangles (no font-glyph dependency) plus the
// count. Clicking opens the CardSurface. Mirrors ProposalsWidget's "only there
// when there's something" discipline — the bar stays quiet until the machine has
// a surface waiting for you.
import QtQuick
import Quickshell

Item {
    id: root

    visible: Cards.count > 0
    implicitWidth: visible ? row.implicitWidth + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // stacked-cards mark: a back card offset up-right, a front card over it
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 13
            height: 13
            Rectangle {
                x: 3
                y: 0
                width: 9
                height: 11
                radius: 2
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
            }
            Rectangle {
                x: 0
                y: 2
                width: 9
                height: 11
                radius: 2
                color: Theme.bg
                border.width: 1.5
                border.color: Theme.accent
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Cards.count
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize - 2
        }
    }

    TapHandler {
        onTapped: Cards.toggle()
    }
}
