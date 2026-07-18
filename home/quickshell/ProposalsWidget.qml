// ProposalsWidget.qml — the machine's inbox glyph. Exists only when
// agent-authored PRs (wish/*, heal/*, claude/*) are waiting for review: a small
// accent glyph with the count. This is the visible end of the trust ladder —
// rung 1 means the machine proposes and the human merges, so the bar shows when
// the machine is waiting on you.
//
// The gh poll and the PR list now live in the Presence singleton (one home for
// the whole second-operator model); this widget is just its bar-side glyph.
// Clicking opens the PresencePanel, where "waiting on you" lists the PRs
// alongside what's working and what recently finished.
import QtQuick
import Quickshell

Item {
    id: root

    visible: Presence.waiting.length > 0
    implicitWidth: visible ? row.implicitWidth + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "✻"
            color: Theme.accent
            font.pixelSize: Theme.fontSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Presence.waiting.length
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize - 2
        }
    }

    TapHandler {
        onTapped: Presence.togglePanel()
    }
}
