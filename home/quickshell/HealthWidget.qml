// HealthWidget.qml — the bar's conscience. Exists only when a claudeos-* /
// claude-* systemd unit (user or system) is in the failed state: a small
// warn-coloured dot breathes until the failure clears. Click lists the failed
// units. Polled cheaply, like Agent.qml.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    // Space-separated failed unit names ("" = all healthy).
    property string failed: ""
    readonly property var failedList: failed === "" ? [] : failed.split(" ")

    visible: failed !== ""
    implicitWidth: visible ? dot.width + 8 : 0
    implicitHeight: Theme.barHeight - 8

    // Sentinel-prefixed single line per poll ("@" alone = healthy), same
    // contract as Agent.qml — bare empty lines can be dropped by the parser.
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "echo \"@$({ systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } 2>/dev/null | awk '{print $1}' | grep -E '^(claudeos|claude)-' | paste -sd' ' -)\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (t.startsWith("@"))
                    root.failed = t.slice(1).trim();
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: Theme.warn
        SequentialAnimation on opacity {
            running: root.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
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
        implicitWidth: col.implicitWidth + 28
        implicitHeight: col.implicitHeight + 20
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

                Text {
                    text: "failed units"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Repeater {
                    model: root.failedList
                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: Theme.warn
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
