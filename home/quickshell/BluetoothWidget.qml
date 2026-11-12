// BluetoothWidget.qml — bespoke bluetooth status (replaces the blueman tray
// icon). The glyph speaks the state: muted = radio off, subtext = on but
// idle, accent = something connected. Click for the popup: tap the header to
// toggle the radio, tap a paired device to connect/disconnect it, and the
// footer turns on pairing mode: the adapter scans, nearby unpaired devices
// are listed, and a tap pairs, trusts and connects one. Paired devices grow
// a "forget" label while pairing mode is on. Nothing here answers a PIN or
// passkey prompt (Quickshell has no BlueZ agent), so a device that needs one
// fails with a pointer to `bluetoothctl`, which carries its own agent.
// Hidden entirely on machines with no adapter.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: root
    // Holds the right pill open while the popup is up (Bar.qml).
    readonly property bool popupOpen: popup.visible
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: (Bluetooth.devices?.values ?? []).filter(d => d.paired)
    readonly property int connectedCount: devices.filter(d => d.connected).length
    // A connected device reporting ≤20% charge (BlueZ Battery1; `battery`
    // is a 0..1 fraction). The right pill surfaces the glyph while this holds.
    readonly property bool lowBattery: devices.some(d => d.connected && d.batteryAvailable && d.battery <= 0.2)

    // A null adapter means the radio is rfkill-blocked (bluez has no
    // controller) — still show the muted glyph so the bar can turn it on.
    readonly property bool radioOn: adapter?.enabled ?? false

    // Pairing mode: scanning is a radio cost, so it only runs while the popup
    // is open and gives up on its own after a minute.
    property bool pairMode: false
    // Unpaired devices that announce a real name. BlueZ fills `name` with the
    // address when a device has none; `deviceName` stays empty, which filters
    // out the anonymous beacons that otherwise flood the list.
    readonly property var found: (Bluetooth.devices?.values ?? []).filter(d => !d.paired && d.deviceName !== "").slice(0, 8)
    // The device a pair() is in flight for, and the last failure to show.
    property var pending: null
    property string pairError: ""

    onPairModeChanged: {
        pairError = "";
        if (adapter)
            adapter.discovering = pairMode;
    }

    function pairWith(dev) {
        pairError = "";
        pending = dev;
        dev.trusted = true; // so it reconnects on its own next time
        dev.pair();
    }

    // Follows the in-flight device from the root, because its row is destroyed
    // the moment it becomes paired and leaves the `found` list.
    Connections {
        target: root.pending
        function onPairedChanged() {
            if (root.pending?.paired) {
                root.pending.connect();
                root.pending = null;
            }
        }
        function onPairingChanged() {
            if (root.pending && !root.pending.pairing && !root.pending.paired) {
                root.pairError = "couldn't pair " + root.pending.name + " — if it wants a PIN, use bluetoothctl";
                root.pending = null;
            }
        }
    }

    Timer {
        interval: 60000
        running: root.pairMode
        onTriggered: root.pairMode = false
    }

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
        // … and warn when a connected device is running out of charge.
        color: !root.radioOn ? Theme.muted : root.lowBattery ? Theme.warn : root.connectedCount > 0 ? Theme.accent : Theme.text
        Behavior on color {
            ColorAnimation {
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
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
        onVisibleChanged: if (!visible)
            root.pairMode = false

        Rectangle {
            anchors.fill: parent
            color: Theme.bgGlass
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
                        // charge, when the device reports one
                        Text {
                            visible: modelData.connected && modelData.batteryAvailable
                            text: Math.round(modelData.battery * 100) + "%"
                            color: modelData.battery <= 0.2 ? Theme.warn : Theme.subtext
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TapHandler {
                            onTapped: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                        // unpairing, offered only while pairing mode is on
                        Text {
                            visible: root.pairMode
                            text: "forget"
                            color: Theme.urgent
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                            TapHandler {
                                onTapped: modelData.forget()
                            }
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

                // pairing mode: nearby unpaired devices, tap to pair
                Repeater {
                    model: root.pairMode ? root.found : []
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: "transparent"
                            border.color: Theme.subtext
                            border.width: 1
                        }
                        Text {
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Text {
                            visible: modelData.pairing
                            text: "pairing…"
                            color: Theme.accent
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        TapHandler {
                            enabled: !modelData.pairing
                            onTapped: root.pairWith(modelData)
                        }
                    }
                }
                Text {
                    visible: root.pairMode && root.found.length === 0
                    text: "looking for devices…"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    visible: root.pairError !== ""
                    text: root.pairError
                    color: Theme.warn
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    width: Math.min(implicitWidth, 260)
                    wrapMode: Text.WordWrap
                }

                // footer: toggle pairing mode (needs the radio on to scan)
                Text {
                    visible: root.radioOn
                    text: root.pairMode ? "done pairing" : "pair a device…"
                    color: root.pairMode ? Theme.accent : Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    TapHandler {
                        onTapped: root.pairMode = !root.pairMode
                    }
                }
            }
        }
    }
}
