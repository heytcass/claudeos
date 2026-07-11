// Bar.qml — the ClaudeOS top bar, one PanelWindow per monitor.
// Left: workspaces · active-window title. Center: clock/date (calendar popup).
// Right: media · volume · network · battery · tray. Colors/fonts from Theme.
import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    // hairline bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.surface
    }

    // ---- left ----
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Workspaces {}
        ActiveWindow {
            Layout.maximumWidth: 440
        }
    }

    // ---- center ----
    ClockWidget {
        anchors.centerIn: parent
    }

    // ---- right ----
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MediaWidget {}
        VolumeWidget {}
        NetworkWidget {}
        BatteryWidget {}
        TrayWidget {
            Layout.leftMargin: 4
        }
    }
}
