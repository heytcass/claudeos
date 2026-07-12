// Bar.qml — the ClaudeOS top bar, one PanelWindow per monitor.
// No longer a strip: the window is transparent and hosts three floating islands
// with wallpaper showing between them — left (workspaces · window),
// center (the adaptive Island · Jasper's emoji), right (volume · network · battery · tray).
// Colors/fonts/metrics from Theme.
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

    // Float gap above/below the pills. The window is taller than a pill so the
    // islands hover clear of the screen edge; the exclusive zone reserves the
    // whole height, so tiled windows start below the floating bar.
    readonly property int floatGap: Theme.gap
    implicitHeight: (Theme.barHeight - 6) + floatGap * 2
    color: "transparent"

    // ---- left island ----
    Pill {
        entranceDelay: 0
        anchors.left: parent.left
        anchors.leftMargin: Theme.gap + 2
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: Theme.gap
            Workspaces {}
            ActiveWindow {
                Layout.maximumWidth: 440
            }
        }
    }

    // ---- center: the adaptive island (clock ⇄ now-playing) ----
    Island {
        anchors.centerIn: parent
    }

    // ---- right island ----
    Pill {
        entranceDelay: 180
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap + 2
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: 4
            VolumeWidget {}
            NetworkWidget {}
            BatteryWidget {}
            TrayWidget {
                Layout.leftMargin: 4
            }
        }
    }
}
