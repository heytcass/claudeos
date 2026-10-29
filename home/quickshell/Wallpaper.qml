// Wallpaper.qml — the living wallpaper, one per monitor, on the background layer.
//
// The scene itself is wallpaper.svg, drawn from the palette by lib/wallpaper.nix
// (the same SVG modules/desktop/theme.nix rasterises for stylix.image, so the
// greeter / lock screen / hyprpaper fallback show this frame, frozen). Qt
// rasterises it here at each screen's real size, so it is sharp on landscape
// and portrait alike. On top, in the same 1000-unit square coordinates
// (WallpaperScene, generated from the same .nix):
//
//   - pulses of light run up a trail, merge at the confluence, climb the ridge
//     on the main path and are received by the caretaker's lantern — branches
//     merging to main, tended by lanes;
//   - the moon's halo breathes;
//   - the lantern flickers, and flares when a pulse arrives.
//
// On battery it all holds still (the static frame stays): a continuously
// animating surface keeps the GPU awake for something nobody is looking at.
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

    // One traveller: up a trail to the confluence, then up the ridge to the
    // lantern, rest, repeat on another trail.
    component Pulse: Item {
        id: pulse
        property int startDelay: 0
        property int rest: 4000
        property int trail: -1          // -1 = the main trail
        property real t: 0              // progress along the trail
        property real u: 0              // progress along the ridge
        property bool climbing: false
        signal arrived

        readonly property real px: climbing ? ridgeAt.x : trailAt.x
        readonly property real py: climbing ? ridgeAt.y : trailAt.y

        visible: root.alive
        // Fade in as it leaves the dune's foot, out as it reaches the lantern.
        opacity: climbing ? Math.min(1, (1 - u) * 8) : Math.min(1, t * 5)

        PathInterpolator {
            id: trailAt
            progress: pulse.t
            path: Path {
                PathSvg { path: pulse.trail < 0 ? WallpaperScene.mainTrail : WallpaperScene.trails[pulse.trail] }
            }
        }
        PathInterpolator {
            id: ridgeAt
            progress: pulse.u
            path: Path {
                PathSvg { path: WallpaperScene.ridgePath }
            }
        }

        Glow {
            cx: pulse.px
            cy: pulse.py
            r: 9
            tint: Theme.base09
        }
        Rectangle {
            x: pulse.px - width / 2
            y: pulse.py - height / 2
            width: 2.6
            height: 2.6
            radius: width / 2
            color: Theme.base07
            antialiasing: true
        }

        SequentialAnimation {
            running: root.alive
            loops: Animation.Infinite
            PauseAnimation { duration: pulse.startDelay }
            ScriptAction {
                // Favour main: one pulse in three takes the bright path.
                script: pulse.trail = Math.random() < 0.33 ? -1 : Math.floor(Math.random() * WallpaperScene.trails.length)
            }
            NumberAnimation { target: pulse; property: "t"; from: 0; to: 1; duration: 5200; easing.type: Easing.InOutSine }
            PropertyAction { target: pulse; property: "climbing"; value: true }
            NumberAnimation { target: pulse; property: "u"; from: 0; to: 1; duration: 3800; easing.type: Easing.InOutQuad }
            ScriptAction { script: pulse.arrived() }
            PropertyAction { target: pulse; property: "climbing"; value: false }
            PropertyAction { target: pulse; property: "t"; value: 0 }
            PropertyAction { target: pulse; property: "u"; value: 0 }
            PauseAnimation { duration: pulse.rest }
        }
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
                id: halo
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

            Pulse { startDelay: 0; rest: 3100; onArrived: lantern.flare() }
            Pulse { startDelay: 4300; rest: 5900; onArrived: lantern.flare() }
            Pulse { startDelay: 9100; rest: 4700; onArrived: lantern.flare() }

            // The caretaker's lantern: an uneven flicker, a flare on each arrival.
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
