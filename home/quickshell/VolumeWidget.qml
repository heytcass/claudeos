// VolumeWidget.qml — default-sink volume as a colored glyph + slim level bar
// (no percent text; scroll to adjust, click to mute). The bar fills with the
// level and the glyph colours by state — accent when loud, muted when muted.
// Requires PwObjectTracker to bind the node, or volume/muted read/write no-op.
import QtQuick
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio ? sink.audio.volume : 0
    readonly property bool muted: !sink?.audio || sink.audio.muted

    implicitWidth: r.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: "transparent"

    // Bind the sink so its audio props become valid/writable.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Row {
        id: r
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: root.muted ? Theme.muted : (root.vol > 0.5 ? Theme.accent : Theme.text)
            text: {
                if (root.muted)
                    return Icons.volumeMute;
                return root.vol > 0.5 ? Icons.volumeHigh : Icons.volumeLow;
            }
        }
        // slim level track + fill
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 3
            radius: 1.5
            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(1, root.vol)) * parent.width
                height: parent.height
                radius: parent.radius
                color: root.muted ? Theme.muted : Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = 0.05;
            const v = root.sink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step);
            root.sink.audio.volume = Math.max(0, Math.min(1, v)); // clamp (PW allows >1)
            wheel.accepted = true;
        }
    }
}
