// CalendarPopup.qml — the dropdown under the clock: a calendar plus the
// notification history (GNOME puts notifications in the same place). Click-away
// dismisses it (grabFocus).
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup
    property Item anchorItem

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: 6

    implicitWidth: 340
    implicitHeight: card.implicitHeight
    visible: false
    grabFocus: true
    color: "transparent"

    // Opening the centre means the user is now looking at notifications, so any
    // held (quiet) FYIs are already visible in the history list below — drop
    // them from the queue without a redundant summary peek (Phase 1b).
    onVisibleChanged: if (visible)
        Notifications.markQuietSeen()

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 24
        color: Theme.bg
        radius: 14
        border.color: Theme.surface
        border.width: 1

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            // Jasper's insight — the one most important thing, above the day it
            // was derived from. The island shows only the emoji; this is where
            // the sentence lives.
            Rectangle {
                Layout.fillWidth: true
                visible: Jasper.text !== ""
                implicitHeight: jasperRow.implicitHeight + 16
                radius: 8
                color: Theme.surface

                RowLayout {
                    id: jasperRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: Jasper.emoji
                        opacity: Jasper.stale ? 0.5 : 1
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Jasper.sentence !== "" ? Jasper.sentence : Jasper.text
                        color: Jasper.stale ? Theme.subtext : Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Calendar {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.surface
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Notifications"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.bold: true
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: "Clear"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    visible: Notifications.history.count > 0
                    TapHandler {
                        onTapped: Notifications.history.clear()
                    }
                }
            }

            Text {
                visible: Notifications.history.count === 0
                text: "No notifications"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
                topPadding: 4
                bottomPadding: 4
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 280)
                visible: Notifications.history.count > 0
                clip: true
                spacing: 6
                model: Notifications.history

                delegate: Rectangle {
                    id: histCard
                    required property string summary
                    required property string body
                    width: ListView.view.width
                    implicitHeight: ncol.implicitHeight + 12
                    radius: 8
                    color: Theme.surface

                    ColumnLayout {
                        id: ncol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: histCard.summary
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.bold: true
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: histCard.body
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
