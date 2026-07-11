// BatteryWidget.qml — battery icon + %, click for time-remaining. No
// QtQuick.Controls (ToolTip unavailable in the quickshell QML path) — the
// detail is a small PopupWindow instead.
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

    visible: bat && bat.isLaptopBattery
    implicitWidth: r.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: hover.hovered || popup.visible ? Theme.surface : "transparent"

    function iconFor(p) {
        if (root.charging)
            return Icons.charging;
        if (p >= 90)
            return Icons.batFull;
        if (p >= 65)
            return Icons.batThreeQuarter;
        if (p >= 40)
            return Icons.batHalf;
        if (p >= 15)
            return Icons.batQuarter;
        return Icons.batEmpty;
    }
    function fmt(s) {
        s = Math.round(s);
        const h = Math.floor(s / 3600);
        const mm = Math.floor((s % 3600) / 60);
        return (h ? h + "h " : "") + mm + "m";
    }

    Row {
        id: r
        anchors.centerIn: parent
        spacing: 5

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: (root.pct <= 15 && !root.charging) ? Theme.urgent : Theme.text
            text: root.iconFor(root.pct)
        }
        Text {
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            color: Theme.text
            text: root.pct + "%"
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
