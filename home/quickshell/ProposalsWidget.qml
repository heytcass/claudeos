// ProposalsWidget.qml — the machine's inbox. Exists only when agent-authored
// PRs (wish/*, heal/*, claude/*) are waiting for the human's review: a small
// accent glyph with the count. Click lists them. This is the visible end of
// the trust ladder — rung 1 means the machine proposes and the human merges,
// so the bar shows when the machine is waiting on you. Same Process + Timer +
// sentinel contract as HealthWidget; gh failures (offline, logged out) leave
// the sentinel empty and hide the widget rather than showing junk.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Agent-authored open PRs: [{number, title}]
    property var proposals: []

    visible: proposals.length > 0
    implicitWidth: visible ? row.implicitWidth + 8 : 0
    implicitHeight: Theme.barHeight - 8

    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "echo \"@$(gh pr list --limit 30 --json number,title,headRefName 2>/dev/null | tr -d '\\n')\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim();
                if (!t.startsWith("@"))
                    return;
                const body = t.slice(1).trim();
                if (body === "") {
                    root.proposals = [];
                    return;
                }
                try {
                    const all = JSON.parse(body);
                    root.proposals = all.filter(p => /^(wish|heal|claude)\//.test(p.headRefName)).map(p => ({
                        number: p.number,
                        title: p.title
                    }));
                } catch (e) {
                    root.proposals = [];
                }
            }
        }
    }
    Timer {
        interval: 600000 // 10 min — one gh call, nothing polls an LLM
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "✦"
            color: Theme.accent
            font.pixelSize: Theme.fontSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.proposals.length
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize - 2
        }
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
        implicitWidth: Math.min(col.implicitWidth + 28, 520)
        implicitHeight: col.implicitHeight + 20
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "the machine proposes"
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Repeater {
                    model: root.proposals
                    delegate: Text {
                        required property var modelData
                        text: "#" + modelData.number + "  " + modelData.title
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 480)
                    }
                }
            }
        }
    }
}
