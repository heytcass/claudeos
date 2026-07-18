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
    // whole height, so tiled windows start below the floating bar. Same value
    // as the side margins: one 4px rhythm shared with Hyprland's gaps_out.
    readonly property int floatGap: Theme.edgeGap
    implicitHeight: (Theme.barHeight - 6) + floatGap * 2
    color: "transparent"

    // ---- left island ----
    Pill {
        entranceDelay: 0
        anchors.left: parent.left
        anchors.leftMargin: Theme.edgeGap
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
        anchors.rightMargin: Theme.edgeGap
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: 6

            // The bar's conscience — only exists when a claudeos-* unit failed.
            HealthWidget {}

            // status.claude.com at a glance — dim-green dot while operational,
            // breathes amber/red on any incident. Click for the service list.
            StatusWidget {}

            // The machine's inbox — only exists when agent-authored PRs
            // (wish/heal/claude branches) are waiting for human review.
            ProposalsWidget {}

            // Generated surfaces — only exists while a card is live; opens the
            // CardSurface stack. Quiet until the machine has a surface waiting.
            CardsWidget {}

            // Caffeine indicator — exists only while idle-inhibit holds
            // (accent = SUPER+I, muted = agent auto-hold), steam included.
            CaffeineWidget {}

            // The brain's fuel gauge — Claude subscription limits, quiet
            // until ≥70%. Hidden entirely when logged out or offline.
            ClaudeUsageWidget {}

            VolumeWidget {}
            NetworkWidget {}
            BluetoothWidget {}
            BatteryWidget {}
            TrayWidget {
                Layout.leftMargin: 4
            }
        }
    }
}
