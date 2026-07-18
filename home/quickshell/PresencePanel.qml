// PresencePanel.qml — the second-operator surface. A dropdown-style overlay,
// opened by clicking the island while a lane works or the proposals glyph on
// the bar (both flip Presence.panelOpen). Three sections, each a species of
// the machine's activity:
//   · working        — lanes running right now (breathing accent)
//   · waiting on you  — agent PRs; click opens the PR in the browser
//   · recently finished — the presence ledger; click opens the artifact
// This is "trust becomes chrome" made concrete: provenance and audit one click
// from the bar. Deterministic QML only — it renders Presence's already-parsed
// model, never model output. Esc or click-away dismisses (mirrors WishOverlay).
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Live clock for age labels, ticking only while the panel is open.
    property int nowSec: 0
    Timer {
        interval: 5000
        running: Presence.panelOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowSec = Math.floor(Date.now() / 1000)
    }
    function ago(ts) {
        const s = Math.max(0, root.nowSec - ts);
        if (s < 60)
            return s + "s";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        return Math.floor(s / 3600) + "h";
    }

    // One shared launcher for PR/artifact links. gh is known present (the
    // proposals poll uses it); xdg-open handles arbitrary artifact urls and
    // no-ops if absent.
    Process {
        id: opener
    }
    function openPr(number) {
        opener.command = ["gh", "pr", "view", "" + number, "--web"];
        opener.running = true;
        Presence.panelOpen = false;
    }
    function openUrl(url) {
        if (!url)
            return;
        opener.command = ["xdg-open", url];
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
            color: Theme.bg
            border.width: 1
            border.color: Theme.surface

            // swallow clicks on the card so they don't hit the dismiss scrim
            MouseArea {
                anchors.fill: parent
            }

            // soft agent halo while a lane is live — the card glows like the island
            property real glow: 0
            SequentialAnimation on glow {
                running: Presence.laneCount > 0 && Presence.panelOpen
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: 1300
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 1300
                    easing.type: Easing.InOutSine
                }
            }
            Repeater {
                model: [
                    {
                        pad: 14,
                        alpha: 0.10
                    },
                    {
                        pad: 30,
                        alpha: 0.05
                    }
                ]
                delegate: Rectangle {
                    required property var modelData
                    z: -1
                    anchors.centerIn: parent
                    width: card.width + modelData.pad + 8 * card.glow
                    height: card.height + modelData.pad + 8 * card.glow
                    radius: 24
                    visible: Presence.laneCount > 0
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, modelData.alpha * (0.4 + 0.6 * card.glow))
                }
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
                        text: "✳"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "the second operator"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.bold: true
                        font.pixelSize: Theme.fontSize
                    }
                }

                Text {
                    visible: !Presence.anyActivity
                    text: "idle — nothing running, nothing waiting."
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                }

                // ---- working ----
                Column {
                    width: parent.width
                    spacing: 6
                    visible: Presence.live.length > 0
                    Text {
                        text: "working"
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 3
                        font.capitalization: Font.AllUppercase
                    }
                    Repeater {
                        model: Presence.live
                        delegate: Row {
                            required property var modelData
                            width: col.width
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✳"
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5 + 0.5 * card.glow)
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 120
                                text: modelData.phrase
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize - 1
                                elide: Text.ElideRight
                            }
                            Item {
                                width: 1
                                height: 1
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.ago(modelData.started)
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                    }
                }

                // ---- waiting on you ----
                Column {
                    width: parent.width
                    spacing: 6
                    visible: Presence.waiting.length > 0
                    Text {
                        text: "waiting on you"
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 3
                        font.capitalization: Font.AllUppercase
                    }
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
                                    width: parent.width - 60
                                    text: modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }
                            TapHandler {
                                onTapped: root.openPr(modelData.number)
                            }
                        }
                    }
                }

                // ---- recently finished ----
                Column {
                    width: parent.width
                    spacing: 6
                    visible: Presence.recent.length > 0
                    Text {
                        text: "recently finished"
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 3
                        font.capitalization: Font.AllUppercase
                    }
                    Repeater {
                        model: Presence.recent.slice(0, 6)
                        delegate: Rectangle {
                            required property var modelData
                            width: col.width
                            implicitHeight: rrow.implicitHeight + 8
                            radius: 8
                            color: (rhover.hovered && modelData.url) ? Theme.surface : "transparent"
                            HoverHandler {
                                id: rhover
                                enabled: !!modelData.url
                            }
                            Row {
                                id: rrow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.lane
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSize - 3
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 150
                                    text: modelData.result
                                    color: Theme.subtext
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                                Item {
                                    width: 1
                                    height: 1
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !!modelData.url
                                    text: "↗"
                                    color: Theme.accent
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.ago(modelData.ts)
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSize - 3
                                }
                            }
                            TapHandler {
                                enabled: !!modelData.url
                                onTapped: root.openUrl(modelData.url)
                            }
                        }
                    }
                }
            }
        }
    }
}
