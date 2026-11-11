// Toasts.qml — live notification popups, top-right, one stack per monitor.
// Auto-expire (except Critical); click to dismiss; action buttons invoke.
// Below the server's notifications sit the bar's own notes (Notifications.
// announce: the quiet-queue flush, a fresh Jasper insight) — same card, no
// icon, no actions; Notifications.qml expires them, a click dismisses.
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

        visible: Notifications.list.values.length > 0 || Notifications.notes.count > 0
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
                    color: Theme.bgGlass
                    border.width: modelData.urgency === NotificationUrgency.Critical ? 2 : 1
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.surface

                    // Auto-expire (Critical stays until dismissed). Low is glance-
                    // and-gone: Notifications.lowLife, or the sender's own timeout
                    // when shorter. expireTimeout is the raw D-Bus value in ms
                    // (Quickshell's doc says seconds; the code stores it as sent):
                    // -1 = server default, 0 = "never", both capped for Low.
                    Timer {
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        interval: {
                            if (card.modelData.urgency !== NotificationUrgency.Low)
                                return 6000;
                            const asked = card.modelData.expireTimeout;
                            return asked > 0 ? Math.min(asked, Notifications.lowLife) : Notifications.lowLife;
                        }
                        onTriggered: card.modelData.expire()
                    }

                    // What the icon column shows, as a plain string: "" means no
                    // icon. Read this, never IconImage.source — that is a url,
                    // and `url !== ""` is always true, so the column never
                    // collapsed. A missing icon NAME still resolves to an
                    // "image://icon/…" URL that loads a MAGENTA placeholder with
                    // status=Ready, so names go through iconPath(name, true),
                    // which returns "" when the theme lacks them — including a
                    // name smuggled in as the image-path hint, which Quickshell
                    // turns into the same image://icon/ form. Image data and
                    // file paths are used as-is; a load Error hides them below.
                    readonly property string iconSource: {
                        let img = card.modelData.image;
                        if (img.startsWith("image://icon/"))
                            img = Quickshell.iconPath(img.slice(13), true);
                        if (img !== "")
                            return img;
                        const icon = card.modelData.appIcon;
                        if (icon === "")
                            return "";
                        if (icon.startsWith("file:"))
                            return icon;
                        if (icon.startsWith("/"))
                            return "file://" + icon;
                        return Quickshell.iconPath(icon, true);
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
                            // No icon, or one that failed to load (a missing file,
                            // undecodable image data) → hidden, and a hidden item is
                            // dropped from the RowLayout, so the text starts at the
                            // card's padding.
                            visible: card.iconSource !== "" && status !== Image.Error
                            source: card.iconSource
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: Notifications.clean(card.modelData.summary)
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: Notifications.clean(card.modelData.body)
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

            // The bar's own notes — the same card, minus icon and actions.
            Repeater {
                model: Notifications.notes

                delegate: Rectangle {
                    id: note
                    required property int uid
                    required property string summary
                    required property string body
                    required property int urgency
                    Layout.fillWidth: true
                    implicitHeight: ncol.implicitHeight + 20
                    radius: 12
                    color: Theme.bgGlass
                    border.width: note.urgency === NotificationUrgency.Critical ? 2 : 1
                    border.color: note.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.surface

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: Notifications.dismissNote(note.uid)
                    }

                    ColumnLayout {
                        id: ncol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: note.summary
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.bold: true
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: note.body
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            textFormat: Text.StyledText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
