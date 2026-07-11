// ClockWidget.qml — center clock/date; click opens the calendar + notification
// dropdown (CalendarPopup), GNOME-style.
import QtQuick
import Quickshell

Rectangle {
    id: root
    implicitWidth: label.implicitWidth + 20
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: hover.hovered || popup.visible ? Theme.surface : "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: popup.visible = !popup.visible
    }

    CalendarPopup {
        id: popup
        anchorItem: root
    }
}
