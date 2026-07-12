// CaffeineWidget.qml — the idle-inhibit mug. Exists only while Caffeine holds:
// accent mug = deliberate SUPER+I hold; muted mug = the agent's auto-hold
// (disappears on its own when the run ends). The coffee is hot: faint steam
// wisps rise off the rim while the hold lasts.
import QtQuick

Item {
    id: root
    visible: Caffeine.inhibited
    implicitWidth: mug.implicitWidth
    implicitHeight: Theme.barHeight - 8

    Text {
        id: mug
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: Icons.coffee
        font.family: Theme.fontMono
        font.pixelSize: Theme.iconSize
        color: Caffeine.manual ? Theme.accent : Theme.subtext
    }

    // Steam: two wisps drifting up from the rim on offset beats. Each is a
    // tiny dot that rises, sways sideways, and fades — looping while held.
    Repeater {
        model: [
            {
                dx: -2,
                delay: 0
            },
            {
                dx: 3,
                delay: 1100
            }
        ]
        delegate: Rectangle {
            id: wisp
            required property var modelData
            width: 2
            height: 2
            radius: 1
            x: parent.width / 2 + modelData.dx
            color: mug.color
            opacity: 0

            SequentialAnimation {
                running: root.visible
                loops: Animation.Infinite
                PauseAnimation {
                    duration: wisp.modelData.delay
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: wisp
                        property: "y"
                        from: 6
                        to: -4
                        duration: 1600
                        easing.type: Easing.OutQuad
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: wisp
                            property: "opacity"
                            from: 0
                            to: 0.55
                            duration: 500
                        }
                        NumberAnimation {
                            target: wisp
                            property: "opacity"
                            to: 0
                            duration: 1100
                        }
                    }
                }
                PauseAnimation {
                    duration: 600
                }
            }
        }
    }
}
