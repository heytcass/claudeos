// ReviewPanel.qml — the PR inbox. A dropdown-style overlay opened from the
// ProposalsWidget glyph (it flips Presence.panelOpen), listing the
// agent-authored PRs waiting for your review. Click a row to open that PR in
// the browser. It used to also show live lanes and a "recently finished"
// ledger under a "second operator" header; both were dropped (2026-10-28) —
// the island already names live work, and the ledger was mostly stale Jasper
// lines. Only the actionable list stays. Deterministic QML only — it renders
// Presence's already-parsed model, never model output. Esc or click-away
// dismisses (mirrors WishOverlay).
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // gh is known present (the PR poll uses it).
    Process {
        id: opener
    }
    function openPr(number) {
        opener.command = ["gh", "pr", "view", "" + number, "--web"];
        opener.running = true;
        Presence.panelOpen = false;
    }

    PanelWindow {
        id: win
        visible: Presence.panelOpen
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // click-away + Esc dismiss
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Presence.panelOpen = false
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Presence.panelOpen = false
        }

        // the card, dropping just below the floating bar, centered
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight + Theme.edgeGap * 2 + 6
            width: 420
            implicitHeight: col.implicitHeight + 28
            radius: 16
            color: Theme.bgGlass
            border.width: 1
            border.color: Theme.surface

            // swallow clicks on the card so they don't hit the dismiss scrim
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // header
                Row {
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✻"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "waiting for review"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.bold: true
                        font.pixelSize: Theme.fontSize
                    }
                }

                Text {
                    visible: Presence.waiting.length === 0
                    text: "nothing waiting for review."
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: Presence.waiting.length > 0
                    Repeater {
                        model: Presence.waiting
                        delegate: Rectangle {
                            required property var modelData
                            width: col.width
                            implicitHeight: wrow.implicitHeight + 8
                            radius: 8
                            color: whover.hovered ? Theme.surface : "transparent"
                            HoverHandler {
                                id: whover
                            }
                            Row {
                                id: wrow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "#" + modelData.number
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 110
                                    text: modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                                // which lane authored it: wish / heal / claude
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.lane
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSize - 3
                                }
                            }
                            TapHandler {
                                onTapped: root.openPr(modelData.number)
                            }
                        }
                    }
                }
            }
        }
    }
}
