// VolumeWidget.qml — default-sink volume as a colored glyph + slim level bar
// (no percent text at rest; scroll to adjust, click to mute). The bar fills
// with the level and the glyph colours by state — accent when loud, muted when
// muted. Requires PwObjectTracker to bind the node, or volume/muted read/write
// no-op.
//
// It is also the OSD (Osd.qml): on every Osd.shown — volume keys, this
// widget's own scroll, any app moving the sink, the brightness keys — it
// widens for a moment: the track grows, a percent / "mute" label appears, and
// for brightness the glyph and level switch to the backlight. Then it settles
// back. This used to be a face of the center island.
import QtQuick
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio ? sink.audio.volume : 0
    readonly property bool muted: !sink?.audio || sink.audio.muted

    // OSD hold: restarted by every Osd.shown, so a held key keeps it open.
    // Every monitor's widget shows it — the key belongs to no one screen.
    property bool osd: false
    Connections {
        target: Osd
        function onShown() {
            root.osd = true;
            osdTimer.restart();
        }
    }
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osd = false
    }
    readonly property bool bright: root.osd && Osd.kind === "brightness"
    readonly property real level: root.bright ? Osd.level : Math.max(0, Math.min(1, root.vol))
    readonly property bool dim: root.bright ? Osd.level === 0 : root.muted

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
            color: root.dim ? Theme.muted : (root.level > 0.5 ? Theme.accent : Theme.text)
            text: {
                if (root.bright)
                    return Icons.brightness;
                if (root.muted)
                    return Icons.volumeMute;
                return root.vol > 0.5 ? Icons.volumeHigh : Icons.volumeLow;
            }
        }
        // slim level track + fill; widens while the OSD holds
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.osd ? 90 : 26
            height: 3
            radius: 1.5
            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35)
            Behavior on width {
                NumberAnimation {
                    duration: Motion.standard
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.level * parent.width
                height: parent.height
                radius: parent.radius
                color: root.dim ? Theme.muted : Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: Motion.instant
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveStandard
                    }
                }
            }
        }
        // Percent, only while the OSD holds. Fixed width so 9% → 10% → 100%
        // doesn't jiggle the pill; it opens from zero width alongside the
        // track and drops out of the Row (no stray spacing) once closed.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.osd ? 34 : 0
            visible: width > 0
            clip: true
            opacity: root.osd ? 1 : 0
            horizontalAlignment: Text.AlignRight
            text: !root.bright && root.muted ? "mute" : Math.round(root.level * 100) + "%"
            color: root.dim ? Theme.muted : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
            Behavior on width {
                NumberAnimation {
                    duration: Motion.standard
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.quick
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
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
