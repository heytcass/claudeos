// BluetoothWidget.qml — bespoke bluetooth status (replaces the blueman tray
// icon). The glyph speaks the state: muted = radio off, subtext = on but
// idle, accent = something connected. Click for the popup: tap the header to
// toggle the radio, tap a paired device to connect/disconnect it, and the
// footer opens blueman-manager for pairing (the one flow that earns a full
// GUI). Hidden entirely on machines with no adapter.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: (Bluetooth.devices?.values ?? []).filter(d => d.paired)
    readonly property int connectedCount: devices.filter(d => d.connected).length

    // A null adapter means the radio is rfkill-blocked (bluez has no
    // controller) — still show the muted glyph so the bar can turn it on.
    readonly property bool radioOn: adapter?.enabled ?? false

    implicitWidth: glyph.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: "transparent"

    // On = unblock + power (adapter may need a beat to appear after unblock);
    // off = bluez power-off AND rfkill block, so the radio is truly quiet.
    function setRadio(on) {
        if (on) {
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            if (adapter)
                adapter.enabled = true;
        } else {
            if (adapter)
                adapter.enabled = false;
            Quickshell.execDetached(["rfkill", "block", "bluetooth"]);
        }
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: Icons.bluetooth
        font.family: Theme.fontMono
        font.pixelSize: Theme.iconSize
        // Same contract as the volume glyph: muted = off, text = on/idle,
        // accent = in use (something connected).
        color: !root.radioOn ? Theme.muted : root.connectedCount > 0 ? Theme.accent : Theme.text
        Behavior on color {
            ColorAnimation {
                duration: 220
            }
        }
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
        implicitWidth: Math.max(col.implicitWidth + 28, 190)
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
                spacing: 6

                // header: state + radio toggle
                Row {
                    spacing: 8
                    Text {
                        text: Icons.bluetooth
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize
                        color: root.radioOn ? Theme.accent : Theme.muted
                    }
                    Text {
                        text: root.radioOn ? "on — tap to turn off" : "off — tap to turn on"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                    TapHandler {
                        onTapped: root.setRadio(!root.radioOn)
                    }
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                }

                // paired devices: tap to connect/disconnect
                Repeater {
                    model: root.devices
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: modelData.connected ? Theme.good : Theme.muted
                        }
                        Text {
                            text: modelData.name
                            color: modelData.connected ? Theme.text : Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                        }
                        TapHandler {
                            onTapped: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                }
                Text {
                    visible: root.devices.length === 0
                    text: "nothing paired"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                }

                // escape hatch: pairing lives in the full GUI
                Text {
                    text: "pair a device…"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    TapHandler {
                        onTapped: {
                            popup.visible = false;
                            Quickshell.execDetached(["blueman-manager"]);
                        }
                    }
                }
            }
        }
    }
}
