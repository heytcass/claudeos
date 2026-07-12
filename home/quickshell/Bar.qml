// Bar.qml — the ClaudeOS top bar, one PanelWindow per monitor.
// No longer a strip: the window is transparent and hosts three floating islands
// with wallpaper showing between them — left (workspaces · window),
// center (the adaptive Island · Jasper's emoji), right (volume · network · battery · tray).
// Colors/fonts/metrics from Theme.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    // Wayland idle-inhibit: while Caffeine holds (SUPER+I manual, or agent
    // activity), Hyprland's idle-notify stays quiet so hypridle never locks,
    // blanks, or suspends. The protocol needs a window surface — hence here
    // and not in the Caffeine singleton. One inhibitor per monitor's bar is
    // fine: the compositor refcounts them.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.inhibited
    }
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

            // Caffeine indicator — exists only while idle-inhibit holds.
            // Accent mug = deliberate SUPER+I hold; muted mug = the agent's
            // auto-hold (it disappears on its own when the run ends).
            Text {
                visible: Caffeine.inhibited
                text: Icons.coffee
                font.family: Theme.fontMono
                font.pixelSize: Theme.iconSize
                color: Caffeine.manual ? Theme.accent : Theme.subtext
            }

            VolumeWidget {}
            NetworkWidget {}
            BatteryWidget {}
            TrayWidget {
                Layout.leftMargin: 4
            }
        }
    }
}
