// VolumeWidget.qml — default-sink volume. Scroll to adjust, click to mute.
// Requires PwObjectTracker to bind the node, or volume/muted read/write no-op.
import QtQuick
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink

    implicitWidth: r.implicitWidth + 14
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: hover.hovered ? Theme.surface : "transparent"

    // Bind the sink so its audio props become valid/writable.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Row {
        id: r
        anchors.centerIn: parent
        spacing: 5

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: Theme.text
            text: {
                if (!root.sink?.audio || root.sink.audio.muted)
                    return Icons.volumeMute;
                return root.sink.audio.volume > 0.5 ? Icons.volumeHigh : Icons.volumeLow;
            }
        }
        Text {
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            color: Theme.text
            text: root.sink?.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "—"
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
