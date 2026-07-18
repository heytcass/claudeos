// Toasts.qml — live notification popups, top-right, one stack per monitor.
// Auto-expire (except Critical); click to dismiss; action buttons invoke.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        visible: Notifications.list.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: 12
            right: 12
        }
        implicitWidth: 380
        implicitHeight: column.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: 8

            Repeater {
                model: Notifications.list

                delegate: Rectangle {
                    id: card
                    required property Notification modelData
                    Layout.fillWidth: true
                    implicitHeight: crow.implicitHeight + 20
                    radius: 12
                    color: Theme.bg
                    border.width: modelData.urgency === NotificationUrgency.Critical ? 2 : 1
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.surface

                    // Auto-expire (Critical stays until dismissed).
                    Timer {
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        interval: card.modelData.urgency === NotificationUrgency.Low ? 4000 : 6000
                        onTriggered: card.modelData.expire()
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: card.modelData.dismiss()
                    }

                    RowLayout {
                        id: crow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 10

                        IconImage {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop
                            // A missing icon name still resolves to an "image://icon/…"
                            // URL that loads a MAGENTA placeholder with status=Ready, so
                            // neither source!="" nor status can catch it. iconPath(name,
                            // true) does an existence check and returns "" when the theme
                            // lacks the icon — hide on that. (A hidden item is dropped from
                            // the RowLayout, so the text fills the space.)
                            visible: source !== ""
                            source: card.modelData.image !== "" ? card.modelData.image : Quickshell.iconPath(card.modelData.appIcon, true)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.body
                                color: Theme.subtext
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                textFormat: Text.StyledText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            // action buttons
                            RowLayout {
                                Layout.topMargin: 2
                                spacing: 6
                                visible: card.modelData.actions.length > 0

                                Repeater {
                                    model: card.modelData.actions

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: atext.implicitWidth + 16
                                        implicitHeight: atext.implicitHeight + 8
                                        radius: 6
                                        color: Theme.surface

                                        Text {
                                            id: atext
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            color: Theme.text
                                            font.family: Theme.fontSans
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: parent.modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
