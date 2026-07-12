// Island.qml — the adaptive center capsule (the bar's signature element).
// A floating pill that MORPHS by context instead of being a static clock:
//   · idle       → clock / date
//   · media      → now-playing (spectrum + title/artist), width springs open
//   · notif      → a new notification peeks inline for a few seconds, then
//                  collapses back (takes priority over clock/media while shown)
// Click opens the media popup while playing, else the calendar/notification
// centre. This is the deliberate break from the GNOME panel look.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Rectangle {
    id: root

    // Active player: the one actually playing (first Playing MPRIS source).
    readonly property var player: {
        const ps = Mpris.players?.values ?? [];
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null;
    }
    readonly property bool playing: player !== null

    // Notification peek state (driven by Notifications.posted).
    property bool peeking: false
    property string peekTitle: ""
    property string peekBody: ""

    state: peeking ? "notif" : (playing ? "media" : "clock")
    states: [
        State {
            name: "clock"
        },
        State {
            name: "media"
        },
        State {
            name: "notif"
        }
    ]

    Connections {
        target: Notifications
        function onPosted(summary, body, appName, urgency) {
            root.peekTitle = summary;
            root.peekBody = body;
            root.peeking = true;
            peekTimer.restart();
        }
    }
    Timer {
        id: peekTimer
        interval: 5000
        onTriggered: root.peeking = false
    }

    implicitHeight: Theme.barHeight - 6
    radius: height / 2
    color: hover.hovered ? Qt.lighter(Theme.surface, 1.15) : Theme.surface

    // Staggered entrance (matches Pill.qml) — the center settles in between the
    // left and right islands.
    property int entranceDelay: 90
    opacity: 0
    scale: 0.92
    Component.onCompleted: entrance.start()
    SequentialAnimation {
        id: entrance
        PauseAnimation {
            duration: root.entranceDelay
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 320
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "scale"
                to: 1
                duration: 460
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
    }

    // Agent pulse: while ClaudeOS is working on itself (a rebuild/build), the
    // border breathes terracotta — the machine's "I'm alive and busy" tell.
    // Drives `pulse` 0→1→0; the border alpha follows it. Highest-priority border
    // treatment (over notif/idle) because it's a persistent state, not transient.
    property real pulse: 0
    SequentialAnimation on pulse {
        running: Agent.active
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: 1100
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: 1100
            easing.type: Easing.InOutSine
        }
    }
    border.width: Agent.active ? 2 : 1
    border.color: Agent.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3 + 0.6 * pulse) : (root.state === "notif" ? Theme.accent : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, playing ? 0.5 : 0.25))

    // Width tracks the visible content; springs open/closed on morph.
    implicitWidth: {
        const w = state === "notif" ? notifContent.implicitWidth : state === "media" ? mediaContent.implicitWidth : clockContent.implicitWidth;
        return w + 26;
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 0.85
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- clock face ----
    Row {
        id: clockContent
        anchors.centerIn: parent
        spacing: 9
        opacity: root.state === "clock" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
        // Jasper's mood emoji — the companion's whole bar presence. The
        // sentence rides at the top of the calendar popup (one tap, one
        // dropdown). Dimmed when the insight has gone stale.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Jasper.emoji !== ""
            text: Jasper.emoji
            opacity: Jasper.stale ? 0.5 : 1
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
        Text {
            id: clockLabel
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
    }

    // ---- now-playing face ----
    Row {
        id: mediaContent
        anchors.centerIn: parent
        spacing: 10
        opacity: root.state === "media" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Spectrum {
            anchors.verticalCenter: parent.verticalCenter
            height: root.height - 8
            bars: 14
            active: root.playing
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: root.player?.trackTitle ?? ""
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                font.bold: true
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
            }
            Text {
                text: root.player?.trackArtist ?? ""
                color: Theme.subtext
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 2
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    // ---- notification peek face ----
    Row {
        id: notifContent
        anchors.centerIn: parent
        spacing: 9
        opacity: root.state === "notif" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // pulsing terracotta dot marks it as a live alert
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Theme.accent
            SequentialAnimation on opacity {
                running: root.state === "notif"
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.35
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: root.peekTitle
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                font.bold: true
                width: Math.min(implicitWidth, 320)
                elide: Text.ElideRight
            }
            Text {
                text: root.peekBody
                color: Theme.subtext
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 2
                width: Math.min(implicitWidth, 320)
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: {
            if (root.state === "notif")
                root.peeking = false;          // tap dismisses the peek
            else if (root.state === "media")
                mediaPopup.visible = !mediaPopup.visible;
            else
                calPopup.visible = !calPopup.visible;
        }
    }

    CalendarPopup {
        id: calPopup
        anchorItem: root
    }
    MediaPopup {
        id: mediaPopup
        anchorItem: root
        player: root.player
    }
}
