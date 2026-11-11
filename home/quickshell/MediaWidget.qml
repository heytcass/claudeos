// MediaWidget.qml — now-playing, as a small live spectrum in the right pill.
// Exists only while an MPRIS player is Playing, or its popup is open (hidden,
// a RowLayout gives it no space). Click opens the MediaPopup — art, title, transport, seek. This used
// to be the island's media face; the island now speaks only for the time and
// for Claude, so music lives with the other device state, beside the volume.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    // Holds the right pill open while the popup is up (Bar.qml).
    readonly property bool popupOpen: mediaPopup.visible

    // Active player: the first Playing MPRIS source (same lookup the island used).
    readonly property var player: {
        const ps = Mpris.players?.values ?? [];
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null;
    }

    // Pausing from the popup drops `player` to null, which would hide this
    // widget out from under its own open popup and blank the controls. So the
    // last player is held, and the widget stays while the popup is open.
    property var lastPlayer: null
    onPlayerChanged: if (player !== null)
        lastPlayer = player

    visible: player !== null || mediaPopup.visible
    implicitWidth: spectrum.implicitWidth + 8
    implicitHeight: Theme.barHeight - 8

    // cava only runs while this is visible (Spectrum gates on it), so a
    // paused player costs nothing.
    Spectrum {
        id: spectrum
        anchors.centerIn: parent
        height: root.height - 10
        bars: 8
        active: root.player !== null
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: mediaPopup.visible = !mediaPopup.visible
    }

    // The popup's own anchor (bottom-right edge, growing left) already keeps
    // it on screen from the right pill, so no override is needed here.
    MediaPopup {
        id: mediaPopup
        anchorItem: root
        player: root.player ?? root.lastPlayer
    }
}
