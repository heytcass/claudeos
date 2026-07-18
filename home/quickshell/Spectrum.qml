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

    // Intensity-by-height: quiet bars rest muted, loud ones burn terracotta —
    // the whole strip reads as heat, not a picket fence of one colour.
    function heat(t) {
        const a = Theme.muted, b = root.barColor;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
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
                readonly property real level: root.levels[index] ?? 0
                width: 3
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: root.heat(Math.min(1, level * 1.6))
                height: Math.max(3, level * root.height)
                Behavior on height {
                    NumberAnimation {
                        duration: 85
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 85
                    }
                }
            }
        }
    }
}
