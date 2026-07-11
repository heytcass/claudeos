// MediaPopup.qml — album art, title/artist, transport controls, and a seek bar.
// position is non-reactive in MPRIS, so a FrameAnimation nudges it while playing.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PopupWindow {
    id: popup
    property Item anchorItem
    property var player

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 6

    implicitWidth: 320
    implicitHeight: card.implicitHeight
    visible: false
    grabFocus: true
    color: "transparent"

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 24
        color: Theme.bg
        radius: 14
        border.color: Theme.surface
        border.width: 1

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    radius: 8
                    color: Theme.surface
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: (popup.player?.trackArtUrl ?? "") !== ""
                        source: popup.player?.trackArtUrl ?? ""
                        sourceSize.width: 144
                        sourceSize.height: 144
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: (popup.player?.trackArtUrl ?? "") === ""
                        text: Icons.music
                        font.family: Theme.fontMono
                        font.pixelSize: 28
                        color: Theme.muted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: popup.player?.trackTitle || "Nothing playing"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.bold: true
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: popup.player?.trackArtist ?? ""
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            // seek bar (only when the player reports a length)
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Theme.surface
                visible: (popup.player?.lengthSupported ?? false) && (popup.player?.length ?? 0) > 0

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                    width: parent.width * Math.min(1, (popup.player?.position ?? 0) / Math.max(1, popup.player?.length ?? 1))
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 22

                Text {
                    text: Icons.prev
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.text
                    opacity: (popup.player?.canGoPrevious ?? false) ? 1 : 0.3
                    TapHandler {
                        onTapped: popup.player?.previous()
                    }
                }
                Text {
                    text: (popup.player?.isPlaying ?? false) ? Icons.pause : Icons.play
                    font.family: Theme.fontMono
                    font.pixelSize: 22
                    color: Theme.accent
                    TapHandler {
                        onTapped: popup.player?.togglePlaying()
                    }
                }
                Text {
                    text: Icons.next
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.text
                    opacity: (popup.player?.canGoNext ?? false) ? 1 : 0.3
                    TapHandler {
                        onTapped: popup.player?.next()
                    }
                }
            }
        }
    }

    // MPRIS position doesn't update reactively — nudge it while playing so the
    // seek bar animates.
    FrameAnimation {
        running: popup.visible && (popup.player?.playbackState ?? 0) === MprisPlaybackState.Playing
        onTriggered: popup.player.positionChanged()
    }
}
