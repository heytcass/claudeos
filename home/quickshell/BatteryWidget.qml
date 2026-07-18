// BatteryWidget.qml — a *drawn* battery that fills and colors by level
// (green → amber → red), so charge reads at a glance without a number. The
// exact %/time still lives in the click popup. No QtQuick.Controls (ToolTip
// unavailable in the quickshell QML path) — the detail is a PopupWindow.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: root
    readonly property var bat: UPower.displayDevice
    // Quickshell's UPowerDevice.percentage is a 0..1 fraction (NOT 0..100) —
    // scale to whole percent once, here, and use `pct` everywhere below.
    readonly property int pct: bat ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged

    // Level → semantic colour. Charging always reads "good".
    readonly property color lvlColor: charging ? Theme.good : (pct <= 15 ? Theme.urgent : (pct <= 35 ? Theme.warn : Theme.good))

    visible: bat && bat.isLaptopBattery
    implicitWidth: graphic.width + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: "transparent"

    function fmt(s) {
        s = Math.round(s);
        const h = Math.floor(s / 3600);
        const mm = Math.floor((s % 3600) / 60);
        return (h ? h + "h " : "") + mm + "m";
    }

    // ---- the battery graphic: shell + proportional fill + tip + charge bolt ----
    Item {
        id: graphic
        anchors.centerIn: parent
        width: shell.width + 2
        height: shell.height

        // Low-battery breathing: the whole graphic pulses when it's genuinely
        // urgent — discharging at ≤15%. Settles back to full opacity otherwise.
        readonly property bool low: !root.charging && root.pct <= 15
        SequentialAnimation on opacity {
            running: graphic.low
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.4
                duration: 850
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 850
                easing.type: Easing.InOutSine
            }
        }
        onLowChanged: if (!low)
            opacity = 1

        Rectangle {
            id: shell
            width: 24
            height: 12
            radius: 3
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(root.lvlColor.r, root.lvlColor.g, root.lvlColor.b, 0.55)

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, (shell.width - 4) * root.pct / 100)
                height: shell.height - 4
                radius: 1.5
                color: root.lvlColor
                clip: true
                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }

                // Charging shimmer: a light band sweeps the fill while juice
                // flows in — palette-derived highlight, no raw hex.
                Rectangle {
                    id: shimmer
                    visible: root.charging
                    width: 6
                    height: parent.height
                    color: Qt.rgba(Theme.base07.r, Theme.base07.g, Theme.base07.b, 0.35)
                    NumberAnimation on x {
                        running: root.charging
                        loops: Animation.Infinite
                        from: -6
                        to: 24
                        duration: 1400
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
        // positive tip
        Rectangle {
            anchors.left: shell.right
            anchors.verticalCenter: shell.verticalCenter
            width: 2
            height: 5
            radius: 1
            color: Qt.rgba(root.lvlColor.r, root.lvlColor.g, root.lvlColor.b, 0.55)
        }
        // charge bolt overlay
        Text {
            anchors.centerIn: shell
            visible: root.charging
            text: Icons.charging
            font.family: Theme.fontMono
            font.pixelSize: 9
            color: Theme.bgAlt
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: detail.implicitWidth + 24
        implicitHeight: 40
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Text {
                id: detail
                anchors.centerIn: parent
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 12
                text: {
                    const p = root.pct + "%";
                    if (root.charging)
                        return root.bat.timeToFull > 0 ? p + "  ·  " + root.fmt(root.bat.timeToFull) + " to full" : p + "  ·  charging";
                    return root.bat.timeToEmpty > 0 ? p + "  ·  " + root.fmt(root.bat.timeToEmpty) + " left" : p;
                }
            }
        }
    }
}
