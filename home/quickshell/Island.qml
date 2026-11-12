// Island.qml — the adaptive center capsule (the bar's signature element).
// A floating pill that MORPHS by context instead of being a static clock — but
// it speaks only for the time and for Claude (2026-11). Everything else it
// used to carry moved to a surface that already existed: media to the right
// pill's MediaWidget, notification peeks to toasts, the volume/brightness OSD
// to the VolumeWidget, Jasper to a toast note + the calendar popup, the
// shelf to its hotkey (Bar.qml). Four faces, highest priority first (the
// exact order, with the needs face's two slots, is at `state:` below):
//   · done       → an interactive session just finished a real turn
//                  (Sessions.finished): a check and its title, for a moment
//   · needs      → the top of the NeedsYou queue (a session waiting on you, a
//                  failed unit, a PR to review, a card), "+N" when more wait;
//                  click goes to it, the chip or a right click lists them all
//   · agent      → a headless lane is working on the machine (Agent.activity,
//                  a curated phrase), or one interactive Claude session has
//                  been busy long enough to be the thing you wait on
//                  (Sessions.promoted, its app title). Busy sessions short of
//                  that only add a spark + count to the clock face, so the
//                  clock stays the default (2026-11-08).
//   · clock      → date and time, plus "✳ N" while sessions are busy
// Click opens the calendar/notification centre (on the needs face: right
// click), which leads with the queue. This is the deliberate break
// from the GNOME panel look.
import QtQuick
import QtQuick.Effects
import Quickshell

Rectangle {
    id: root

    // Face priority, highest first:
    //   done  — a finished turn is news and brief (4 s), so nothing outranks it
    //   needs — the NeedsYou queue's top item when it is BLOCKING (a session
    //           waiting on your answer) or a FAILURE: you are the bottleneck,
    //           so it outranks watching the machine work
    //   agent — a lane or a promoted session at work
    //   needs — the queue's top item when it is only reviewable/informational
    //           (a PR, a card): worth the stage only when nothing is working
    //   clock — the default; an empty queue leaves every rule above as before
    // The border breath and flare run under every face, so a working machine
    // still says so while the island asks for you.
    readonly property bool needsAny: NeedsYou.count > 0
    readonly property bool needsUrgent: root.needsAny && NeedsYou.top.tier <= NeedsYou.tierFailure
    state: root.doneShown ? "done" : root.needsUrgent ? "needs" : root.agentFace ? "agent" : root.needsAny ? "needs" : "clock"

    // Only the island on the FOCUSED output animates — see BarFocus.qml for
    // why (one QSGRenderThread per monitor, all breathing the same pulse).
    // Off-focus islands hold a steady mid-breath: same colour language, no
    // per-frame work.
    readonly property bool onFocusedScreen: BarFocus.isFocused(QsWindow.window)
    // The border/halo breath runs under any face while the agent works …
    readonly property bool agentAnimating: root.working && root.onFocusedScreen
    // … whereas the agent FACE's own motion only exists in that state.
    readonly property bool agentFaceAnimating: root.state === "agent" && root.onFocusedScreen

    // Who may take the stage. Headless lanes always do (they have no window of
    // their own); an interactive session only once Sessions promotes it. Any
    // busy session still breathes the border — "working" — without the face.
    readonly property bool working: Agent.active || Sessions.busy > 0
    readonly property bool agentFace: Agent.active || Sessions.promoted !== ""
    // Agent-face phrase. One lane → its own phrase (Agent.activity, the newest
    // marker). More than one → "N lanes" with that newest phrase riding along.
    // No lane → the promoted session's title.
    readonly property string agentPhrase: Agent.active ? (Presence.laneCount > 1 ? (Presence.laneCount + " lanes · " + Agent.activity) : Agent.activity) : Sessions.promoted
    states: [
        State {
            name: "clock"
        },
        State {
            name: "agent"
        },
        State {
            name: "done"
        },
        State {
            name: "needs"
        }
    ]

    // "What needs me" from the summon: the focused monitor's island opens its
    // popup, which leads with the whole queue.
    Connections {
        target: NeedsYou
        function onSummoned() {
            if (root.onFocusedScreen)
                calPopup.visible = true;
        }
    }

    // Done face: Sessions.finished names a session whose turn just ended
    // after real work. Every island shows it, each on its own hold timer; the
    // face is static (no shimmer, no spin), so there is nothing to gate on
    // focus. A second finish mid-hold replaces the title and restarts the hold.
    property bool doneShown: false
    property string doneName: ""
    Connections {
        target: Sessions
        function onFinished(name) {
            root.doneName = name;
            root.doneShown = true;
            doneTimer.restart();
        }
    }
    Timer {
        id: doneTimer
        interval: 4000
        onTriggered: root.doneShown = false
    }

    implicitHeight: Theme.barHeight - 6
    radius: height / 2
    color: hover.hovered ? Qt.lighter(Theme.surfaceGlass, 1.15) : Theme.surfaceGlass

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
                duration: Motion.standard
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
            NumberAnimation {
                target: root
                property: "scale"
                to: 1
                duration: Motion.emphasis
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveEmphasized
            }
        }
    }

    // Agent pulse: while ClaudeOS is working on itself (a rebuild/build), the
    // border breathes terracotta — the machine's "I'm alive and busy" tell.
    // Drives `pulse` 0→1→0; the border alpha follows it. Highest-priority border
    // treatment (over idle) because it's a persistent state, not transient.
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
    // Flare: a one-shot terracotta swell when the agent STARTS or FINISHES —
    // the breath above says "busy", this marks the edges of the work. Rises in
    // an instant, fades over a pulse; tinted onto whatever the border already
    // is, so it lands cleanly on the breathing border (start) and on the idle
    // one (finish). Focused output only, like the breath.
    property real flare: 0
    onWorkingChanged: {
        if (root.onFocusedScreen)
            flareAnim.restart();
    }
    SequentialAnimation {
        id: flareAnim
        NumberAnimation {
            target: root
            property: "flare"
            to: 1
            duration: Motion.instant
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveStandard
        }
        NumberAnimation {
            target: root
            property: "flare"
            to: 0
            duration: Motion.pulse
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.curveBreathe
        }
    }

    border.width: root.working || root.flare > 0 ? 2 : 1
    // At rest the border is a faint muted line; on the needs face it takes the
    // top item's tier colour, still and half-strong (the "your turn" tell).
    border.color: Qt.tint(root.working ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3 + 0.6 * root.glow) : root.state === "needs" ? Qt.rgba(root.needsTint.r, root.needsTint.g, root.needsTint.b, 0.5) : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.25),Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, root.flare))

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
            opacity: root.working || root.flare > 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.standard
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.curveStandard
                }
            }
            Rectangle {
                id: haloFill
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 1)
                // The breath only counts while working (after finish, `glow`
                // strands mid-cycle); the flare adds on top, brighter and wider
                // than any breath so the edge of the work reads as an event.
                readonly property real breath: root.working ? root.glow : 0
                opacity: Math.min(1, halo.modelData.alpha * ((root.working ? 0.4 : 0) + 0.6 * breath + 1.6 * root.flare))
                transform: Scale {
                    origin.x: halo.width / 2
                    origin.y: halo.height / 2
                    xScale: 1 + (8 * haloFill.breath + 14 * root.flare) / Math.max(1, halo.width)
                    yScale: 1 + (8 * haloFill.breath + 14 * root.flare) / Math.max(1, halo.height)
                }
            }
        }
    }

    // Width tracks the visible content; springs open/closed on morph. A real
    // spring, not a duration+curve: when a finished turn interrupts an agent
    // morph the spring retargets carrying its current velocity, so
    // back-to-back state flips flow into each other instead of restarting
    // from rest.
    implicitWidth: {
        const w = state === "done" ? doneContent.implicitWidth : state === "needs" ? needsContent.implicitWidth : state === "agent" ? agentContent.implicitWidth : clockContent.implicitWidth;
        return w + 26;
    }
    Behavior on implicitWidth {
        SpringAnimation {
            spring: Motion.springMorph
            damping: Motion.dampingMorph
            mass: Motion.massMorph
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
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }
        Text {
            id: clockLabel
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd, MMM d   h:mm AP")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
        // Busy Claude sessions: the spark and how many, in the accent at the
        // border's breath. The count is the whole message here — which ones
        // is the popup's job (click) — so the clock keeps the stage.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Sessions.busy > 0
            text: "✳ " + Sessions.busy
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 1)
            opacity: 0.55 + 0.45 * root.glow
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize - 1
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
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
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
                duration: Motion.drift
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
                duration: 2400 // a linear sweep's speed, not a Motion tier
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
            // Hidden-source + layered-mask is the pattern the island's old
            // album-art disc used, so it is known good against this Qt build.
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
            // choice.
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

    // ---- done face: a session's turn just ended ----
    // Static on purpose: the agent face's motion means "working"; this is the
    // still beat after it. The title is cut like the agent phrase.
    Row {
        id: doneContent
        anchors.centerIn: parent
        spacing: 9
        opacity: root.state === "done" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.check
            color: Theme.good
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.doneName.length > 42 ? root.doneName.slice(0, 41) + "…" : root.doneName
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            font.italic: true
        }
    }

    // ---- needs face: the top of the NeedsYou queue ----
    // Calm on purpose: no shimmer, no spin, no breath of its own. Motion in
    // the island means "working"; this face means "your turn", so it is
    // still, and set apart by its tier's colour on the glyph and the border.
    // The time stays, demoted, as on the agent face.
    readonly property color needsTint: NeedsYou.tint(NeedsYou.top)
    Row {
        id: needsContent
        anchors.centerIn: parent
        spacing: 9
        opacity: root.state === "needs" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curveStandard
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: NeedsYou.glyph(NeedsYou.top)
            color: root.needsTint
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
        }
        Text {
            readonly property string t: NeedsYou.top ? NeedsYou.top.title : ""
            anchors.verticalCenter: parent.verticalCenter
            text: t.length > 42 ? t.slice(0, 41) + "…" : t
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
        // More than one thing waiting: a small "+N" chip. It is also the way
        // to the whole list — a click on it opens the popup instead of acting
        // on the top item (see the TapHandler below).
        Rectangle {
            id: needsChip
            anchors.verticalCenter: parent.verticalCenter
            visible: NeedsYou.count > 1
            implicitWidth: chipText.implicitWidth + 12
            implicitHeight: chipText.implicitHeight + 2
            radius: height / 2
            color: Theme.surface
            Text {
                id: chipText
                anchors.centerIn: parent
                text: "+" + (NeedsYou.count - 1)
                color: Theme.subtext
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize - 2
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "h:mm AP")
            color: Theme.subtext
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
        }
    }

    HoverHandler {
        id: hover
    }
    // Left click: on the needs face, go to the top item (its own open path);
    // the "+N" chip, and every other face, opens the popup as before. Right
    // click always opens the popup, so the calendar stays one click away.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: eventPoint => {
            const onChip = needsChip.visible && needsChip.contains(needsChip.mapFromItem(root, eventPoint.position));
            if (root.state === "needs" && !onChip)
                NeedsYou.act(NeedsYou.top);
            else
                calPopup.visible = !calPopup.visible;
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: calPopup.visible = !calPopup.visible
    }
    CalendarPopup {
        id: calPopup
        anchorItem: root
    }
}
