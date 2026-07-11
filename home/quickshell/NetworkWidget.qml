// NetworkWidget.qml — active connection name + type icon, polled from nmcli
// every 5s (Quickshell has no rich NetworkManager service yet, so shell out).
// For wifi it also shows signal strength so it's more than just the SSID.
import QtQuick
import Quickshell.Io

Row {
    id: root
    property string conName: ""
    property string conType: ""
    property int signal: -1

    spacing: 5
    visible: conName !== ""

    Text {
        font.family: Theme.fontMono
        font.pixelSize: Theme.iconSize
        color: Theme.text
        text: root.conType === "ethernet" ? Icons.ethernet : Icons.wifi
    }
    Text {
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
        color: Theme.text
        text: {
            if (root.conType === "wifi" && root.signal >= 0)
                return root.conName + "  " + root.signal + "%";
            return root.conName;
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
