// Island.qml — the adaptive center capsule (the bar's signature element).
// A floating pill that MORPHS by context instead of being a static clock:
//   · idle       → clock / date
//   · media      → now-playing (spectrum + title/artist), width springs open
//   · agent      → ClaudeOS is working on itself: breathing spark + what it's
//                  doing (Agent.activity) + a dim clock so time isn't lost
//   · notif      → a new notification peeks inline for a few seconds, then
//                  collapses back (takes priority over clock/media while shown)
// Click opens the media popup while playing, else the calendar/notification
// centre. This is the deliberate break from the GNOME panel look.
import QtQuick
import QtQuick.Effects
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
    property int peekUrgency: 1
    // Urgency → colour: the dot (and notif border) speak the severity.
    readonly property color peekColor: peekUrgency === 2 ? Theme.urgent : peekUrgency === 0 ? Theme.muted : Theme.accent

    // Face priority: a peek always wins (transient); media outranks agent —
    // while music plays the agent keeps the breathing border but not the stage.
    state: peeking ? "notif" : (playing ? "media" : Agent.active ? "agent" : "clock")

    // Only the island on the FOCUSED output animates — see BarFocus.qml for
    // why (one QSGRenderThread per monitor, all breathing the same pulse).
    // Off-focus islands hold a steady mid-breath: same colour language, no
    // per-frame work.
    readonly property bool onFocusedScreen: BarFocus.isFocused(QsWindow.window)
    // The border/halo breath runs under any face while the agent works …
    readonly property bool agentAnimating: Agent.active && root.onFocusedScreen
    // … whereas the agent FACE's own motion only exists in that state.
    readonly property bool agentFaceAnimating: root.state === "agent" && root.onFocusedScreen

    // Agent-face phrase. One lane → its own phrase (Agent.activity, the newest
    // marker). More than one → "N lanes" with that newest phrase riding along,
    // so the island tells you the second operator is doing several things at
    // once; the PresencePanel (tap) breaks them out.
    readonly property string agentPhrase: Presence.laneCount > 1 ? (Presence.laneCount + " lanes · " + Agent.activity) : Agent.activity
    states: [
        State {
            name: "clock"
        },
        State {
            name: "media"
        },
        State {
            name: "agent"
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
            root.peekUrgency = urgency;
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
    // Everything visual reads `glow`, never `pulse` directly. A stopped
    // animation leaves its property wherever the last frame put it, so an
    // off-focus island would otherwise strand on a random alpha; `glow` pins it
    // to mid-breath instead, and the two never fight over one property.
    readonly property real glow: root.onFocusedScreen ? root.pulse : 0.5
    SequentialAnimation on pulse {
        running: root.agentAnimating
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
    border.color: Agent.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3 + 0.6 * root.glow) : (root.state === "notif" ? peekColor : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, playing ? 0.5 : 0.25))

    // Outer glow while the agent works: two soft halo layers behind the pill
    // (negative z paints below the parent's own fill), swelling and fading on
    // the same breath as the border. Reads as light the island gives off, not
    // a drawn ring.
    Repeater {
        model: [
            {
                pad: 10,
                alpha: 0.16
            },
            {
                pad: 22,
                alpha: 0.07
            }
        ]
        // The breath rides on a Scale transform and opacity — never on width/
        // height or colour. Animating geometry re-tessellates the rounded rect
        // and dirties layout every frame; animating `color` rebuilds the
        // material. Both are node-level updates here instead, so a frame costs
        // one matrix and one alpha. xScale/yScale are computed per axis so the
        // swell stays a uniform 8px on both, exactly as the old geometry did —
        // a single uniform scale would balloon the wide axis.
        delegate: Item {
            id: halo
            required property var modelData
            z: -1
            anchors.centerIn: parent
            width: root.width + halo.modelData.pad
            height: root.height + halo.modelData.pad
            // Outer item owns the on/off fade, so the Behavior never sees the
            // per-frame breath and try to animate towards each frame's value.
            opacity: Agent.active ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 1)
                opacity: halo.modelData.alpha * (0.4 + 0.6 * root.glow)
                transform: Scale {
                    origin.x: halo.width / 2
                    origin.y: halo.height / 2
                    xScale: 1 + 8 * root.glow / Math.max(1, halo.width)
                    yScale: 1 + 8 * root.glow / Math.max(1, halo.height)
                }
            }
        }
    }

    // Width tracks the visible content; springs open/closed on morph.
    implicitWidth: {
        const w = state === "notif" ? notifContent.implicitWidth : state === "media" ? mediaContent.implicitWidth : state === "agent" ? agentContent.implicitWidth : clockContent.implicitWidth;
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
            text: Qt.formatDateTime(clock.date, "ddd, MMM d   h:mm AP")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
        // The context you're in (Phase 3), at low emphasis — the focused
        // workspace is named after a saved context. Absent on numbered/scratch
        // workspaces, so it only shows when you're actually inside one.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Contexts.activeName !== ""
            text: "· " + Contexts.activeName
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            font.italic: true
        }
    }

    // ---- agent face: the machine says what it's doing to itself ----
    Row {
        id: agentContent
        anchors.centerIn: parent
        spacing: 9
        opacity: root.state === "agent" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // Claude's spark, breathing on the border's rhythm and turning slowly
        // — deliberate, unhurried work, not a busy spinner.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "✳"
            // Constant colour + animated opacity: same look, but the glyph
            // keeps one material instead of allocating a new one every frame.
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 1)
            opacity: 0.45 + 0.55 * root.glow
            font.pixelSize: Theme.fontSize + 1
            RotationAnimation on rotation {
                running: root.agentFaceAnimating
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 14000
            }
        }
        // The activity text shimmers — a narrow brightness wave traveling
        // through the letters, the same "thinking" tell Claude's own UI uses.
        //
        // This was 42 per-character Texts, each re-evaluating a `wave` and a
        // `color` binding every frame: ~5k JS binding evaluations a second per
        // monitor, and the single biggest cost in the bar. Same effect, one
        // animated node: a static base Text, a brighter copy of it, and a
        // gradient band swept across a MultiEffect mask so only the band's
        // stripe of the bright copy shows. A frame is now one `x` binding plus
        // a small FBO redraw — no per-glyph JS at all.
        Item {
            id: shimmer
            anchors.verticalCenter: parent.verticalCenter
            // Sized from the base Text's *implicit* size, which is content-
            // derived and so never reads back this Item's width — no loop.
            implicitWidth: baseText.implicitWidth
            implicitHeight: baseText.implicitHeight

            readonly property string shown: root.agentPhrase.length > 42 ? root.agentPhrase.slice(0, 41) + "…" : root.agentPhrase
            readonly property color peak: Qt.lighter(Theme.accent, 1.2)

            // 0→1 sweeps the band from just off the left edge to just off the right.
            property real phase: 0
            NumberAnimation on phase {
                running: root.agentFaceAnimating
                loops: Animation.Infinite
                from: 0
                to: 1
                duration: 2400
            }

            Text {
                id: baseText
                text: shimmer.shown
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                font.italic: true
            }

            // The bright copy, revealed only where the mask band is opaque.
            // Hidden-source + layered-mask is the pattern the album-art disc
            // below already uses, so it is known good against this Qt build.
            Text {
                id: peakText
                text: shimmer.shown
                color: shimmer.peak
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                font.italic: true
                visible: false
            }

            // Stencil, not palette: only this subtree's ALPHA is read, so the
            // white/transparent stops are a mask ramp rather than a colour
            // choice (same role as the album-art `artMask` rectangle).
            Item {
                id: shimmerMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    // Soft-edged band; only its `x` moves per frame.
                    width: Math.max(24, shimmerMask.width * 0.35)
                    height: shimmerMask.height
                    x: -width + (shimmerMask.width + width) * shimmer.phase
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: "white"
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: peakText
                maskEnabled: true
                maskSource: shimmerMask
                // Off-focus the band is frozen mid-sweep; hide the highlight
                // entirely so it reads as plain text rather than a stuck smear.
                opacity: root.agentFaceAnimating ? 1 : 0
            }
        }
        // Time stays legible during long rebuilds, just demoted.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "h:mm AP")
            color: Theme.subtext
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
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

        // Inline album art — a coin-sized disc; the popup keeps the big one.
        // A Rectangle's radius doesn't clip children, so the circle is cut by
        // a MultiEffect mask (QtQuick.Effects) fed by a hidden round stencil.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.height - 10
            height: width
            visible: (root.player?.trackArtUrl ?? "") !== ""

            Image {
                id: artImage
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: artImage
                maskEnabled: true
                maskSource: artMask
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
            // Long titles scroll (pause → drift to the end → pause → snap back)
            // instead of eliding; short ones sit still.
            Item {
                id: titleClip
                clip: true
                width: Math.min(titleText.implicitWidth, 260)
                height: titleText.implicitHeight
                Text {
                    id: titleText
                    text: root.player?.trackTitle ?? ""
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    readonly property real overflow: Math.max(0, implicitWidth - titleClip.width)
                    onTextChanged: x = 0
                    SequentialAnimation on x {
                        running: titleText.overflow > 0 && root.state === "media"
                        loops: Animation.Infinite
                        PauseAnimation {
                            duration: 2000
                        }
                        NumberAnimation {
                            to: -titleText.overflow
                            duration: Math.max(1200, titleText.overflow * 28)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation {
                            duration: 1400
                        }
                        NumberAnimation {
                            to: 0
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }
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
    // A glanceable one-liner — pulsing urgency dot · bold title · muted body —
    // on a single baseline, so it sits centred in the pill like the clock and
    // agent faces instead of squeezing two lines into a single-line-tall island.
    // The full text lives in the notification centre; the peek is just the tell.
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

        // pulsing dot marks it as a live alert, coloured by urgency
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: root.peekColor
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
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.peekTitle
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 220)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text.length > 0
            text: root.peekBody
            color: Theme.subtext
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 300)
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: {
            if (root.state === "notif")
                root.peeking = false;          // tap dismisses the peek
            else if (root.state === "agent")
                Presence.togglePanel();         // second-operator surface
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
