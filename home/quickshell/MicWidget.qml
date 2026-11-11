// MicWidget.qml — the default source (microphone) as one glyph: a mic when
// live, a struck-through mic when muted. Click toggles mute. The right pill
// keeps it folded away unless the mic is muted (Bar.qml) — a muted mic is the
// state worth saying out loud, since it is the one that silently eats a call.
// Like VolumeWidget, the node must be bound with PwObjectTracker or its audio
// props read invalid and writes no-op.
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: !!source?.audio
    readonly property bool muted: ready && source.audio.muted

    // No source at all (no capture device) → nothing to show or toggle.
    visible: source !== null
    implicitWidth: glyph.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8

    PwObjectTracker {
        objects: root.source ? [root.source] : []
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.muted ? Icons.micOff : Icons.mic
        font.family: Theme.fontMono
        font.pixelSize: Theme.iconSize
        color: root.muted ? Theme.warn : Theme.text
        Behavior on color {
            ColorAnimation {
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }
    }

    TapHandler {
        onTapped: if (root.ready)
            root.source.audio.muted = !root.source.audio.muted
    }
}
