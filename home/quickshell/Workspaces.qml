// Workspaces.qml — Hyprland workspace pills. The focused one widens, goes
// terracotta, springs on switch, and sits in a soft accent glow. Click to
// switch.
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    spacing: 6

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData.id

            implicitWidth: pillRect.implicitWidth
            implicitHeight: 20

            // Bounce the focused pill when it becomes focused.
            onFocusedChanged: if (focused)
                pop.restart()
            SequentialAnimation {
                id: pop
                NumberAnimation {
                    target: pillRect
                    property: "scale"
                    to: 1.18
                    duration: 90
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: pillRect
                    property: "scale"
                    to: 1
                    duration: 240
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }

            // soft glow behind the focused pill
            Rectangle {
                anchors.centerIn: pillRect
                width: pillRect.width + 10
                height: pillRect.height + 10
                radius: height / 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                opacity: cell.focused ? 1 : 0
                scale: pillRect.scale
                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                    }
                }
            }

            Rectangle {
                id: pillRect
                anchors.centerIn: parent
                implicitWidth: cell.focused ? 28 : 20
                width: implicitWidth
                height: 20
                radius: 10
                color: cell.focused ? Theme.accent : Theme.surface

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 220
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.name
                    color: cell.focused ? Theme.bgAlt : Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + cell.modelData.id)
                }
            }
        }
    }
}
