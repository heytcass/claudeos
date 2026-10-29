pragma Singleton
// Presence.qml — the agent-activity model behind two bar surfaces:
//   · live    → lanes working right now (the $$.json sidecars in
//               claudeos-agent.d, written by claudeos_agent_begin — same dir
//               Agent.qml polls, but the structured file). The island reads
//               laneCount for its "N lanes" phrase.
//   · waiting → agent-authored PRs awaiting your review (gh pr list), which the
//               ProposalsWidget glyph counts and ReviewPanel lists.
// No model calls anywhere — pure file/gh polling (agent.d every 2.5s, gh every
// 10 min). The presence-done.jsonl ledger claudeos_agent_done writes is no
// longer read here; it survives as an insight-history/debugging file.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{lane, phrase, started}] — lanes with a fresh sidecar (< 60 min old,
    // same stuck-marker backstop as Agent.qml).
    property var live: []
    // [{number, title, lane}] — agent-authored open PRs; lane is the branch
    // prefix (wish / heal / claude).
    property var waiting: []

    readonly property int laneCount: live.length

    // The review panel is a single overlay window (ReviewPanel.qml in
    // shell.qml); the proposals glyph toggles it through this flag.
    property bool panelOpen: false
    function togglePanel() {
        panelOpen = !panelOpen;
    }

    // --- live lanes, one probe, sentinel-delimited batches -----------------
    // The probe prints "L" + sidecar json for each live lane, then a bare
    // "END". We accumulate into a buffer and commit on END, so an empty batch
    // (just END) correctly clears to []. jq isn't assumed on the shell's PATH
    // (Agent.qml's probe doesn't use it either); the shell only concatenates,
    // QML parses.
    property var _lb: []
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "d=\"$XDG_RUNTIME_DIR/claudeos-agent.d\"; find \"$d\" -maxdepth 1 -name '*.json' -type f -mmin -60 2>/dev/null | while IFS= read -r f; do printf 'L'; cat \"$f\"; done; printf 'END\\n'"
        ]
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root.live = root._lb;
                    root._lb = [];
                    return;
                }
                if (line.charAt(0) !== "L")
                    return;
                try {
                    root._lb.push(JSON.parse(line.slice(1)));
                } catch (e) {
                // a half-written sidecar mid-write — skip it; the next 2.5s
                // poll picks up the settled file.
                }
            }
        }
    }
    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    // --- waiting: agent-authored PRs -----------------------------------------
    Process {
        id: ghProbe
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
                    root.waiting = [];
                    return;
                }
                try {
                    const all = JSON.parse(body);
                    root.waiting = all.filter(p => /^(wish|heal|claude)\//.test(p.headRefName)).map(p => ({
                        number: p.number,
                        title: p.title,
                        lane: p.headRefName.split("/")[0]
                    }));
                } catch (e) {
                    root.waiting = [];
                }
            }
        }
    }
    Timer {
        interval: 600000 // 10 min — one gh call, nothing polls an LLM
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ghProbe.running = true
    }
}
