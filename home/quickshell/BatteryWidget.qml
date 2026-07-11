// BatteryWidget.qml — battery icon + %, hover shows time-remaining. Only
// visible on machines with a laptop battery. Goes red near empty on battery.
import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower

Rectangle {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property bool charging: bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged

    visible: bat && bat.isLaptopBattery
    implicitWidth: r.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: hover.hovered ? Theme.surface : "transparent"

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
        const m = Math.floor((s % 3600) / 60);
        return (h ? h + "h " : "") + m + "m";
    }

    Row {
        id: r
        anchors.centerIn: parent
        spacing: 5

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: (root.bat.percentage <= 15 && !root.charging) ? Theme.urgent : Theme.text
            text: root.iconFor(root.bat.percentage)
        }
        Text {
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            color: Theme.text
            text: Math.round(root.bat.percentage) + "%"
        }
    }

    HoverHandler {
        id: hover
    }
    ToolTip.visible: hover.hovered
    ToolTip.text: root.charging ? (root.bat.timeToFull > 0 ? root.fmt(root.bat.timeToFull) + " to full" : "Charging") : (root.bat.timeToEmpty > 0 ? root.fmt(root.bat.timeToEmpty) + " left" : "")
}
