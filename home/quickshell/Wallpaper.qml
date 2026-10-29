// Wallpaper.qml — the living wallpaper, one per monitor, on the background layer.
//
// The scene itself is wallpaper.svg, drawn from the palette by lib/wallpaper.nix
// (the same SVG modules/desktop/theme.nix rasterises for stylix.image, so the
// greeter / lock screen / hyprpaper fallback show this frame, frozen). Qt
// rasterises it here at each screen's real size, so it is sharp on landscape
// and portrait alike. On top, in the same 1000-unit square coordinates
// (WallpaperScene, generated from the same .nix), the scene is driven by real
// work — branches merging to main, tended by lanes (Presence):
//
//   - each live agent lane is a pulse climbing its own trail (picked by a hash
//     of the lane, so a run keeps its path), resting at the confluence and
//     climbing again for as long as the lane works;
//   - when a lane finishes, its pulse climbs main to the caretaker, whose
//     lantern flares — the flare means "work landed";
//   - agent PRs awaiting review are small lights held on main just below the
//     confluence, waiting to merge; when one clears, the lantern flares;
//   - idle (no lanes), only the moon's halo breathes and a faint wanderer
//     occasionally drifts up a side trail — stillness means nothing is running.
//
// On battery it all holds still (the static frame and held PR lights stay): a
// continuously animating surface keeps the GPU awake for something nobody is
// looking at.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    // Not `quickshell`: the shell-glass layer rule would blur behind it.
    WlrLayershell.namespace: "claudeos-wallpaper"
    // Clicks on the bare desktop pass through — this is scenery, not UI.
    mask: Region {}
    color: Theme.base00

    readonly property bool alive: !UPower.onBattery

    // --- lanes → travellers ---------------------------------------------------
    // Presence.live is replaced wholesale every poll, so binding a Repeater to
    // it would restart every pulse every 2.5s. Instead keep a keyed model:
    // new lanes append, vanished lanes are marked finishing (their pulse
    // climbs to the lantern, then retires itself).
    ListModel {
        id: lanes // {key, trail, finishing}
    }

    function laneKey(l) {
        return (l.lane || "") + "|" + (l.started || "");
    }
    function trailFor(key) {
        // FNV-1a + a murmur finaliser: keys differing in one digit (lanes
        // started a second apart) must still land on far-apart trails.
        let h = 2166136261;
        for (let i = 0; i < key.length; i++)
            h = Math.imul(h ^ key.charCodeAt(i), 16777619);
        h = Math.imul(h ^ (h >>> 16), 2246822507);
        h = Math.imul(h ^ (h >>> 13), 3266489909);
        return ((h ^ (h >>> 16)) >>> 0) % WallpaperScene.trails.length;
    }
    function syncLanes() {
        const keys = Presence.live.map(laneKey);
        const known = [];
        for (let i = 0; i < lanes.count; i++) {
            const e = lanes.get(i);
            known.push(e.key);
            if (!e.finishing && keys.indexOf(e.key) < 0)
                lanes.setProperty(i, "finishing", true);
        }
        for (const k of keys)
            if (known.indexOf(k) < 0)
                lanes.append({
                    key: k,
                    trail: trailFor(k),
                    finishing: false
                });
    }
    function retire(key) {
        for (let i = 0; i < lanes.count; i++)
            if (lanes.get(i).key === key && lanes.get(i).finishing) {
                lanes.remove(i);
                return;
            }
    }

    Connections {
        target: Presence
        function onLiveChanged() {
            root.syncLanes();
        }
        // A PR leaving the review queue (merged or closed) lands like a lane.
        function onWaitingChanged() {
            if (Presence.waiting.length < root.heldCount)
                lantern.flare();
            root.heldCount = Presence.waiting.length;
        }
    }
    property int heldCount: 0
    Component.onCompleted: {
        heldCount = Presence.waiting.length;
        syncLanes();
    }

    // A soft radial glow centred on (cx, cy), in scene units.
    component Glow: Shape {
        id: glow
        property real cx
        property real cy
        property real r
        property color tint
        property real strength: 1
        x: cx - r
        y: cy - r
        width: r * 2
        height: r * 2
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.r
                centerY: glow.r
                centerRadius: glow.r
                focalX: glow.r
                focalY: glow.r
                GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.55 * glow.strength) }
                GradientStop { position: 0.35; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.22 * glow.strength) }
                GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
            }
            PathAngleArc {
                centerX: glow.r
                centerY: glow.r
                radiusX: glow.r
                radiusY: glow.r
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // A point of light with a halo, in scene units.
    component Spark: Item {
        id: spark
        property real cx
        property real cy
        property real glowR: 13
        property real strength: 1.3
        Glow {
            cx: spark.cx
            cy: spark.cy
            r: spark.glowR
            tint: Theme.base09
            strength: spark.strength
        }
        Rectangle {
            x: spark.cx - width / 2
            y: spark.cy - height / 2
            width: 3.4
            height: 3.4
            radius: width / 2
            color: Theme.base07
            antialiasing: true
        }
    }

    // One traveller up a side trail. A lane's traveller laps its trail (rest
    // a beat at the confluence, start again) until `finishing`, then takes the
    // ridge to the lantern. A wanderer goes once, faintly, and never climbs.
    component Traveller: Item {
        id: tr
        property int trail: 0
        property bool finishing: false
        property bool wanderer: false
        property bool autoStart: true
        property real t: 0              // progress along the trail
        property real u: 0              // progress along the ridge
        property bool climbing: false
        signal arrived
        signal gone

        function go() {
            t = 0;
            lap.start();
        }
        function lapDone() {
            if (finishing) {
                climbing = true;
                climb.start();
            } else if (wanderer) {
                gone();
            } else {
                rest.start();
            }
        }

        visible: root.alive
        // Fade in leaving the dune's foot; fade out into the confluence unless
        // it is about to climb; fade out again reaching the lantern.
        opacity: (wanderer ? 0.4 : 1) * (climbing ? Math.min(1, (1 - u) * 8) : Math.min(1, t * 5, finishing ? 1 : (1 - t) * 6))

        PathInterpolator {
            id: trailAt
            progress: tr.t
            path: Path {
                PathSvg { path: WallpaperScene.trails[tr.trail] }
            }
        }
        PathInterpolator {
            id: ridgeAt
            progress: tr.u
            path: Path {
                PathSvg { path: WallpaperScene.ridgePath }
            }
        }

        Spark {
            cx: tr.climbing ? ridgeAt.x : trailAt.x
            cy: tr.climbing ? ridgeAt.y : trailAt.y
            // Bigger on main: it has to read against the bright path.
            glowR: tr.climbing ? 18 : 13
            strength: tr.climbing ? 1.8 : 1.3
        }

        // Paused (not stopped) on battery, so no lap is lost or double-fired.
        NumberAnimation {
            id: lap
            target: tr
            property: "t"
            from: 0
            to: 1
            duration: tr.wanderer ? 7500 : 5200
            easing.type: Easing.InOutSine
            paused: running && !root.alive
            onFinished: tr.lapDone()
        }
        NumberAnimation {
            id: climb
            target: tr
            property: "u"
            from: 0
            to: 1
            duration: 3800
            easing.type: Easing.InOutQuad
            paused: running && !root.alive
            onFinished: {
                tr.arrived();
                tr.gone();
            }
        }
        Timer {
            id: rest
            interval: 900
            onTriggered: tr.go()
        }
        Component.onCompleted: if (autoStart) go()
    }

    // The square scene, scaled to cover the screen and centred — the same
    // "fill" crop Stylix gives hyprpaper, so the static and living frames line up.
    Item {
        id: stage
        readonly property real k: Math.max(root.width, root.height) / 1000
        anchors.centerIn: parent
        width: 1000 * k
        height: 1000 * k

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("wallpaper.svg")
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
        }

        Item {
            id: scene
            width: 1000
            height: 1000
            scale: stage.k
            transformOrigin: Item.TopLeft

            // The moon's halo, breathing over the static one in the SVG.
            Glow {
                cx: WallpaperScene.moon.x
                cy: WallpaperScene.moon.y
                r: WallpaperScene.moonRadius * 2.6
                tint: Theme.base09
                strength: 0.35
                SequentialAnimation on strength {
                    running: root.alive
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.7; duration: 7000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.35; duration: 7000; easing.type: Easing.InOutSine }
                }
            }

            // PRs awaiting review, held on main below the confluence (capped:
            // past six the queue says "a lot" just as well).
            Repeater {
                model: Math.min(Presence.waiting.length, 6)
                delegate: Item {
                    id: held
                    required property int index
                    PathInterpolator {
                        id: heldAt
                        progress: 0.965 - held.index * 0.035
                        path: Path {
                            PathSvg { path: WallpaperScene.mainTrail }
                        }
                    }
                    Spark {
                        cx: heldAt.x
                        cy: heldAt.y
                        glowR: 11
                        strength: 0.9
                        SequentialAnimation on strength {
                            running: root.alive
                            loops: Animation.Infinite
                            PauseAnimation { duration: held.index * 700 }
                            NumberAnimation { to: 1.5; duration: 2600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.9; duration: 2600; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            // Live lanes.
            Repeater {
                model: lanes
                delegate: Traveller {
                    required property var model
                    readonly property string key: model.key
                    trail: model.trail
                    finishing: model.finishing
                    onArrived: lantern.flare()
                    onGone: Qt.callLater(root.retire, key)
                }
            }

            // Idle: now and then a faint wanderer, so the desert isn't dead.
            Traveller {
                id: wanderer
                wanderer: true
                autoStart: false
                t: 1 // at rest, faded out
            }
            Timer {
                interval: 16000 + Math.random() * 14000
                running: root.alive && lanes.count === 0
                repeat: true
                onTriggered: {
                    interval = 16000 + Math.random() * 14000;
                    wanderer.trail = Math.floor(Math.random() * WallpaperScene.trails.length);
                    wanderer.go();
                }
            }

            // The caretaker's lantern: an uneven flicker, a flare when work lands.
            Glow {
                id: lantern
                cx: WallpaperScene.lantern.x
                cy: WallpaperScene.lantern.y
                r: 11
                tint: Theme.base09
                strength: 0.8

                property real flicker: 1
                property real boost: 0
                scale: 1 + boost
                opacity: Math.min(1, flicker * 0.8 + boost)

                function flare() { flareAnim.restart(); }

                SequentialAnimation on flicker {
                    running: root.alive
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.75; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.85; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
                SequentialAnimation {
                    id: flareAnim
                    NumberAnimation { target: lantern; property: "boost"; to: 1.4; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lantern; property: "boost"; to: 0; duration: 1600; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
