// WishOverlay.qml — the wish lane's face. SUPER+W summons a centered prompt
// (Hyprland: `bind = $mod, W, global, quickshell:wish`); type a wish, Enter
// hands it to claude-wish (modules/common/system.nix), which returns as a
// wish/* PR announced by notification and the bar's ProposalsWidget. Carries
// the island's agent-glow language: breathing accent border, soft halo,
// rotating spark. Esc or click-away dismisses.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    property bool shown: false
    property bool sent: false

    GlobalShortcut {
        appid: "quickshell"
        name: "wish"
        description: "Make a wish — the OS writes itself a PR"
        onPressed: {
            root.sent = false;
            root.shown = !root.shown;
        }
    }

    // Fire-and-forget: claude-wish owns the whole flow (agent, notifications,
    // PR). If it isn't on PATH yet (wish lane not deployed), this is a no-op.
    Process {
        id: granter
    }

    // The genie exit: on Enter the card flies up into the island — the wish
    // visibly enters the machine, which starts shimmering "✨ wishing" a beat
    // later (claude-wish drops the agent marker). Cause, meet effect.
    ParallelAnimation {
        id: flight
        NumberAnimation {
            target: card
            property: "scale"
            to: 0.06
            duration: 520
            easing.type: Easing.InBack
        }
        NumberAnimation {
            target: card
            property: "anchors.verticalCenterOffset"
            to: -(win.height / 2) + Theme.barHeight
            duration: 520
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0.15
            duration: 520
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.shown = false;
            root.sent = false;
            input.text = "";
            card.scale = 1;
            card.opacity = 1;
            card.anchors.verticalCenterOffset = 0;
        }
    }

    PanelWindow {
        id: win
        visible: root.shown
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        onVisibleChanged: if (visible)
            input.forceActiveFocus()

        // dim backdrop — click anywhere to dismiss
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }
        }

        // A night sky on the scrim — you wish on stars. Golden-ratio scatter
        // (deterministic: no random reflow on reopen), slow asynchronous
        // twinkle, a few stars are the house asterisks. Above the scrim,
        // below the card.
        Repeater {
            model: 36
            delegate: Text {
                required property int index
                readonly property real fx: (index * 0.618034 + 0.05) % 1
                readonly property real fy: (index * 0.381966 + 0.17) % 1
                x: fx * win.width
                y: fy * win.height
                text: index % 9 === 0 ? "✳" : index % 5 === 0 ? "✻" : "·"
                color: Theme.accent
                font.pixelSize: 9 + (index % 3) * 4
                opacity: 0.04
                SequentialAnimation on opacity {
                    running: root.shown
                    loops: Animation.Infinite
                    PauseAnimation {
                        duration: (index % 7) * 260
                    }
                    NumberAnimation {
                        to: 0.14 + (index % 4) * 0.11
                        duration: 1200 + (index % 5) * 380
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.04
                        duration: 1500 + (index % 3) * 420
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // the card, breathing like the island does while an agent works
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 560
            height: col.implicitHeight + 56
            radius: 20
            color: Theme.bg
            border.width: 2
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35 + 0.45 * glow)

            property real glow: 0
            SequentialAnimation on glow {
                running: root.shown
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
            }

            // halo layers, painted below the card
            Repeater {
                model: [
                    {
                        pad: 16,
                        alpha: 0.13
                    },
                    {
                        pad: 34,
                        alpha: 0.05
                    }
                ]
                delegate: Rectangle {
                    required property var modelData
                    z: -1
                    anchors.centerIn: parent
                    width: card.width + modelData.pad + 10 * card.glow
                    height: card.height + modelData.pad + 10 * card.glow
                    radius: 30
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, modelData.alpha * (0.4 + 0.6 * card.glow))
                }
            }

            Column {
                id: col
                anchors.centerIn: parent
                width: card.width - 56
                spacing: 14

                Row {
                    spacing: 10
                    Text {
                        text: "✳"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize + 8
                        RotationAnimation on rotation {
                            running: root.shown
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 14000
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sent ? "wish received" : "make a wish"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 6
                    }
                }

                Rectangle {
                    visible: !root.sent
                    width: parent.width
                    height: 44
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                        clip: true
                        Keys.onEscapePressed: root.shown = false
                        onAccepted: {
                            const w = text.trim();
                            if (w === "")
                                return;
                            granter.command = ["claude-wish", w];
                            granter.running = true;
                            root.sent = true;
                            flight.start();
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: "what should this machine become?"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 1
                        }
                    }
                }

                Text {
                    visible: !root.sent
                    text: "Enter to wish  ·  Esc to dismiss  ·  it arrives as a pull request"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    visible: root.sent
                    text: "✨ the machine is working on it — watch the island, then the bar's ✻"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }
}
