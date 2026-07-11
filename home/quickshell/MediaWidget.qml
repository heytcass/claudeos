// MediaWidget.qml — compact now-playing on the bar (icon + title); click opens
// the MediaPopup with album art + controls. Hidden when nothing is playing.
import QtQuick
import Quickshell.Services.Mpris

Rectangle {
    id: root
    readonly property var player: {
        const ps = Mpris.players?.values ?? [];
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps.find(p => p.canControl) ?? null;
    }

    visible: player !== null
    implicitWidth: visible ? row.implicitWidth + 14 : 0
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: hover.hovered || popup.visible ? Theme.surface : "transparent"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: Theme.accent
            text: root.player?.isPlaying ? Icons.play : Icons.pause
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            color: Theme.text
            width: Math.min(implicitWidth, 180)
            elide: Text.ElideRight
            text: root.player?.trackTitle ?? ""
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    MediaPopup {
        id: popup
        anchorItem: root
        player: root.player
    }
}
