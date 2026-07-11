// Spectrum.qml — a compact audio equalizer for the island's now-playing state.
// Renders `levels` (an array of 0..1 values) as animated terracotta bars, driven
// by REAL audio: cava captures the default output and streams normalized bar
// heights (one frame per line, ';'-separated) which we parse here. cava only
// runs while the spectrum is actually shown (media playing), to stay idle-cheap.
// The cava config lives beside this file (cava.conf, generated in home/hyprland.nix).
import QtQuick
import Quickshell.Io

Item {
    id: root
    property int bars: 14
    property color barColor: Theme.accent
    property bool active: true
    property var levels: []
    readonly property string cavaConf: Qt.resolvedUrl("cava.conf").toString().replace("file://", "")

    implicitWidth: row.implicitWidth

    Component.onCompleted: {
        let a = [];
        for (let i = 0; i < bars; i++)
            a.push(0.04);
        levels = a;
    }

    Process {
        id: cava
        running: root.active && root.visible
        command: ["cava", "-p", root.cavaConf]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.split(";");
                let a = [];
                for (let i = 0; i < root.bars; i++) {
                    const v = Number(parts[i]);
                    a.push(isNaN(v) ? 0 : Math.min(1, v / 1000));
                }
                root.levels = a;
            }
        }
    }
    // When cava stops (media ended), settle the bars to a flat resting line.
    onActiveChanged: if (!active) {
        let a = [];
        for (let i = 0; i < bars; i++)
            a.push(0.04);
        levels = a;
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: 2
        Repeater {
            model: root.bars
            delegate: Rectangle {
                required property int index
                width: 3
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: root.barColor
                height: Math.max(3, (root.levels[index] ?? 0) * root.height)
                Behavior on height {
                    NumberAnimation {
                        duration: 85
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
