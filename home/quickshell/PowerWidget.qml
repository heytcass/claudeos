// PowerWidget.qml — the bar's power menu. Always present in the right
// island: tap the glyph for lock/reboot/shut down, same two-tap-to-commit
// shape as BluetoothWidget/HealthWidget so a stray click can't kill the
// session. Lock reuses the SUPER+L bind's own command (home/hyprland.nix);
// reboot/poweroff ride logind's default single-active-session polkit
// policy, so no password prompt on this single-user laptop.
import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: glyph.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8

    Text {
        id: glyph
        anchors.centerIn: parent
        text: Icons.power
        font.family: Theme.fontMono
        font.pixelSize: Theme.iconSize
        color: popup.visible ? Theme.accent : Theme.subtext
    }

    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: col.implicitWidth + 28
        implicitHeight: col.implicitHeight + 22
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [
                        {
                            label: "lock",
                            icon: Icons.lock,
                            cmd: ["hyprlock"],
                            danger: false
                        },
                        {
                            label: "reboot",
                            icon: Icons.refresh,
                            cmd: ["systemctl", "reboot"],
                            danger: true
                        },
                        {
                            label: "shut down",
                            icon: Icons.power,
                            cmd: ["systemctl", "poweroff"],
                            danger: true
                        }
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        Text {
                            width: 16
                            text: modelData.icon
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSize
                            color: modelData.danger ? Theme.urgent : Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.danger ? Theme.urgent : Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                        }
                        TapHandler {
                            onTapped: {
                                popup.visible = false;
                                Quickshell.execDetached(modelData.cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
