// NetworkWidget.qml — drawn signal-strength bars (wifi) or a plug glyph
// (ethernet), tinted by strength, polled from nmcli every 5s (Quickshell has no
// rich NetworkManager service yet, so shell out). The SSID/percent moved out of
// the strip — the bars say "connected + how strong" at a glance; hover for the
// name. For wifi the lit-bar count and colour both track signal.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string conName: ""
    property string conType: ""
    property int signal: -1

    visible: conName !== ""
    implicitWidth: content.width + 10
    implicitHeight: Theme.barHeight - 8

    // Strength → semantic colour.
    readonly property color strength: signal >= 70 ? Theme.good : (signal >= 40 ? Theme.warn : Theme.urgent)

    Item {
        id: content
        anchors.centerIn: parent
        width: root.conType === "ethernet" ? eth.implicitWidth : bars.width
        height: parent.height

        // ---- wifi: four rising bars, lit up to signal ----
        Row {
            id: bars
            anchors.verticalCenter: parent.verticalCenter
            visible: root.conType !== "ethernet"
            spacing: 2
            // thresholds each bar lights at
            readonly property var cut: [12, 38, 62, 82]
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 4 + index * 3
                    radius: 1.5
                    anchors.bottom: parent.bottom
                    readonly property bool lit: root.signal >= bars.cut[index]
                    color: lit ? root.strength : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35)
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }
                }
            }
        }

        // ---- ethernet: plug glyph ----
        Text {
            id: eth
            anchors.centerIn: parent
            visible: root.conType === "ethernet"
            text: Icons.ethernet
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: Theme.good
        }
    }

    HoverHandler {
        id: hover
    }
    // Hover reveals the connection name (+ signal for wifi) in a small popup.
    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        implicitWidth: nameText.implicitWidth + 20
        implicitHeight: 30
        visible: hover.hovered
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 8
            border.color: Theme.surface
            border.width: 1
            Text {
                id: nameText
                anchors.centerIn: parent
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 12
                text: root.conType === "wifi" && root.signal >= 0 ? root.conName + "  ·  " + root.signal + "%" : root.conName
            }
        }
    }

    // Active connection name + type.
    Process {
        id: conProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                if (line === "") {
                    root.conName = "";
                    root.conType = "";
                    return;
                }
                const parts = line.split(":");
                root.conName = parts[0] ?? "";
                root.conType = (parts[1] ?? "").includes("ethernet") ? "ethernet" : "wifi";
            }
        }
    }

    // Wifi signal strength of the active AP.
    Process {
        id: sigProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi | grep '^yes' | head -n1 | cut -d: -f2"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                root.signal = s === "" ? -1 : parseInt(s);
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            conProc.running = true;
            sigProc.running = true;
        }
    }
}
