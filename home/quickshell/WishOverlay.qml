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
    // Reply mode: the wish card's Reply button (`qs ipc call wish reply`, the
    // `wish-reply` entry in lib/card-actions.nix) opens this same prompt
    // aimed at the latest wish; Enter hands it to `claude-wish --reply`,
    // which resumes that wish's agent session. Super+W always opens a fresh wish.
    property bool replying: false
    property string replyTo: ""

    GlobalShortcut {
        appid: "quickshell"
        name: "wish"
        description: "Make a wish — the OS writes itself a PR"
        onPressed: {
            root.sent = false;
            root.replying = false;
            root.shown = !root.shown;
        }
    }

    IpcHandler {
        target: "wish"
        function reply(): void {
            latest.running = true;
        }
    }

    // The latest wish's own words, so the prompt shows what you are replying to.
    Process {
        id: latest
        command: ["sh", "-c", "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/claudeos/wishes\"; s=$(cat \"$d/latest\" 2>/dev/null) && jq -r '.wish // empty' \"$d/$s.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.replyTo = text.trim();
                root.sent = false;
                root.replying = true;
                root.shown = true;
            }
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
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveAnticipate
        }
        NumberAnimation {
            target: card
            property: "anchors.verticalCenterOffset"
            to: -(win.height / 2) + Theme.barHeight
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveExit
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0.15
            duration: Motion.emphasis
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveExit
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
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveBreathe
                    }
                    NumberAnimation {
                        to: 0.04
                        duration: 1500 + (index % 3) * 420
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.curveBreathe
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
            color: Theme.bgGlass
            border.width: 2
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35 + 0.45 * glow)

            property real glow: 0
            SequentialAnimation on glow {
                running: root.shown
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: Motion.breathe
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveBreathe
                }
                NumberAnimation {
                    to: 0
                    duration: Motion.breathe
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveBreathe
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
                            duration: Motion.drift
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.replying ? (root.sent ? "reply received" : "reply to your wish") : (root.sent ? "wish received" : "make a wish")
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 6
                    }
                }

                Text {
                    visible: root.replying && !root.sent
                    width: parent.width
                    text: "↩ " + (root.replyTo !== "" ? root.replyTo : "the latest wish")
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
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
                            granter.command = root.replying ? ["claude-wish", "--reply", w] : ["claude-wish", w];
                            granter.running = true;
                            root.sent = true;
                            flight.start();
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: root.replying ? "change it, ask about it, or answer its question" : "what should this machine become?"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 1
                        }
                    }
                }

                Text {
                    visible: !root.sent
                    text: root.replying ? "Enter to reply  ·  Esc to dismiss  ·  the same agent picks it up" : "Enter to wish  ·  Esc to dismiss  ·  it arrives as a pull request"
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
