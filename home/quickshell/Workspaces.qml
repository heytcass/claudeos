// Workspaces.qml — Hyprland workspace pills; the focused one widens + goes
// terracotta. Click to switch.
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData.id

            implicitWidth: focused ? 28 : 20
            implicitHeight: 20
            radius: 10
            color: focused ? Theme.accent : Theme.surface

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: modelData.name
                color: parent.focused ? Theme.bgAlt : Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
