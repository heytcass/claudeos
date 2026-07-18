// Presence.qml — the "second operator" model: one answer to "what is the other
// operator doing, what has it done, what is it waiting on?" It unifies three
// fragments that used to live apart:
//   · live    → lanes working right now  (the $$.json sidecars in claudeos-agent.d,
//               written by claudeos_agent_begin — same dir Agent.qml polls, but
//               the structured file, so we get lane name + start time)
//   · recent  → recently finished lane work (presence-done.jsonl, appended by
//               claudeos_agent_done, capped at 20 lines by the writer)
//   · waiting → agent-authored PRs awaiting your review (gh pr list) — the same
//               poll ProposalsWidget used to own, hoisted here so it has ONE home.
// PresencePanel.qml renders the three; Island/ProposalsWidget open it by
// flipping `panelOpen`. No model calls anywhere — pure file/gh polling, reusing
// the existing agent.d 2.5s and gh 10min cadences (no new timers of note).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{lane, phrase, started}] — lanes with a fresh sidecar (< 60 min old,
    // same stuck-marker backstop as Agent.qml).
    property var live: []
    // [{lane, result, url, ts}] — newest first.
    property var recent: []
    // [{number, title}] — agent-authored open PRs.
    property var waiting: []

    readonly property int laneCount: live.length
    readonly property bool anyActivity: live.length > 0 || waiting.length > 0 || recent.length > 0

    // The panel is a single overlay window (PresencePanel.qml in shell.qml);
    // both the island and the proposals glyph toggle it through this flag.
    property bool panelOpen: false
    function togglePanel() {
        panelOpen = !panelOpen;
    }

    // --- live + recent, one probe, sentinel-delimited batches -------------
    // The probe prints one line per record — "L" + sidecar json for each live
    // lane, "R" + ledger json for each recent entry — then a bare "END". We
    // accumulate into buffers and commit on END, so an empty batch (just END)
    // correctly clears to []. jq isn't assumed on the shell's PATH (Agent.qml's
    // probe doesn't use it either); the shell only concatenates, QML parses.
    property var _lb: []
    property var _rb: []
    Process {
        id: probe
        command: [
            "sh",
            "-c",
            "d=\"$XDG_RUNTIME_DIR/claudeos-agent.d\"; find \"$d\" -maxdepth 1 -name '*.json' -type f -mmin -60 2>/dev/null | while IFS= read -r f; do printf 'L'; cat \"$f\"; done; led=\"${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor/presence-done.jsonl\"; tail -n 20 \"$led\" 2>/dev/null | while IFS= read -r l; do printf 'R%s\\n' \"$l\"; done; printf 'END\\n'"
        ]
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root.live = root._lb;
                    root.recent = root._rb.reverse(); // ledger is chronological; newest first
                    root._lb = [];
                    root._rb = [];
                    return;
                }
                const tag = line.charAt(0);
                try {
                    const obj = JSON.parse(line.slice(1));
                    if (tag === "L")
                        root._lb.push(obj);
                    else if (tag === "R")
                        root._rb.push(obj);
                } catch (e) {
                // a half-written line during a truncation race — skip it; the
                // next 2.5s poll picks up the settled file.
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

    // --- waiting: agent-authored PRs (same contract as the old ProposalsWidget) ---
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
                        title: p.title
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
