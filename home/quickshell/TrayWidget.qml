// TrayWidget.qml — StatusNotifierItem system tray. Left-click activates,
// right-click triggers the secondary action. Needs //@ pragma UseQApplication
// (set in shell.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    spacing: 8

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            required property var modelData
            implicitWidth: 18
            implicitHeight: 18
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            IconImage {
                anchors.fill: parent
                source: parent.modelData.icon
            }

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    modelData.activate();
                else
                    modelData.secondaryActivate();
            }
        }
    }
}
