// Bar.qml — the ClaudeOS top bar: one PanelWindow per monitor.
// Left: Hyprland workspaces · Center: clock · Right: media/network/battery/tray.
// Colors resolve against the Stylix-generated Colors.qml singleton (same dir).
// This is the first cut, scoped to just the bar; it grows into a fuller shell
// (notifications, launcher, OSD) later. Widgets are inline for now.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Io

PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 32
    color: Colors.base01

    // ---- left: Hyprland workspaces ----
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                required property var modelData
                width: 26
                height: 20
                radius: 6
                color: modelData.focused ? Colors.base0D : Colors.base02

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? Colors.base00 : Colors.base04
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                }
            }
        }
    }

    // ---- center: clock (native SystemClock, minute precision) ----
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
        color: Colors.base05
        font.pixelSize: 13
    }

    // ---- right: media · network · battery · tray ----
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // Active MPRIS player (click toggles play/pause).
        Text {
            id: media
            property MprisPlayer active: {
                const ps = Mpris.players.values;
                return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0] ?? null;
            }
            visible: active !== null
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            text: active ? (active.trackArtist + " — " + active.trackTitle) : ""
            color: Colors.base04
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                onClicked: if (media.active && media.active.canTogglePlaying) media.active.togglePlaying()
            }
        }

        // Active connection name via nmcli (native Quickshell.Networking exists
        // in 0.3 but is thinly documented — the Process approach is the safe
        // first cut; revisit once the native API is proven).
        Text {
            id: net
            property string info: ""
            visible: info !== ""
            text: info
            color: Colors.base04
            font.pixelSize: 12

            Process {
                id: netProc
                command: [ "sh", "-c", "nmcli -t -f NAME connection show --active | head -n1" ]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: net.info = this.text.trim()
                }
            }

            Timer {
                interval: 5000
                running: true
                repeat: true
                onTriggered: netProc.running = true
            }
        }

        // Battery (only on laptops with a battery; greener on AC/charging).
        Text {
            property var bat: UPower.displayDevice
            visible: bat && bat.isLaptopBattery
            text: bat ? (Math.round(bat.percentage) + "%") : ""
            color: UPower.onBattery ? Colors.base05 : Colors.base0B
            font.pixelSize: 13
        }

        // System tray (needs //@ pragma UseQApplication in shell.qml).
        Row {
            spacing: 8

            Repeater {
                model: SystemTray.items

                delegate: MouseArea {
                    required property var modelData
                    width: 18
                    height: 18
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: modelData.icon
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
    }
}
