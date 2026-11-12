pragma Singleton
// WorkspaceNames.qml — a short purpose label per occupied workspace ("what is
// this one for?"), for the bar's workspace pills (Workspaces.qml) and the
// summon's "Go to:" rows (Summon.qml). Derived locally from what Hyprland and
// Sessions.qml already know: no model call, no network, nothing written.
//
// PRIVACY: labels come from window titles and session names, so they live in
// memory only and are shown on this screen only. Never write a label or a
// title to a file, a log, or claudeos-usage (which only ever gets the fixed
// id "route:workspace" for a summon jump).
//
// The rule is one function, derive(), below. Its inputs, kept here:
//   labels     wsId → {label (≤ maxLen, elided), full (untruncated), addr
//              (the window it came from), appId}; absent = no label
//   _ancestry  session pid → its parent-process chain, probed from /proc once
//              per change of the session set (a pid's parents never change),
//              so a window can be matched to the Claude sessions it hosts
//   _lastTurn  session pid → when its latest observed turn began
//
// Stability: a new text from the SAME window waits `settleMs` before it
// replaces the label (a cd in a terminal, a session switch in the Claude app,
// a retitle), and is dropped if the old text comes back first. A different
// source window, a first label, or an emptied workspace apply at once.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property int maxLen: 18
    readonly property int settleMs: 2000

    property var labels: ({})
    property var _pending: ({})
    property var _ancestry: ({})
    property var _lastTurn: ({})
    property string _pidSig: ""
    property bool _rerun: false
    // No labels until the first session poll and its ancestry probe have
    // landed, so a bar start doesn't flash the app name for a few seconds
    // before the session title takes over.
    property bool _ready: false

    // Lower-cased app ids whose window title names a working directory
    // (terminals: fish's default title ends in the prompt_pwd) or a project
    // (VS Code family: "file - folder - Visual Studio Code"). Extend freely.
    readonly property var terminalIds: ["com.mitchellh.ghostty", "kitty", "foot", "footclient", "alacritty", "org.wezfurlong.wezterm", "org.gnome.console", "org.gnome.terminal", "xterm"]
    readonly property var editorIds: ["code", "code-oss", "code-url-handler", "codium", "vscodium", "cursor"]
    // Session names that say nothing about purpose (Sessions.qml's fallback).
    readonly property var genericSessionNames: ["claude code", "claude", ""]

    // ---- the label rule -------------------------------------------------
    //
    // derive(ws) → {label, full, addr, appId} or null (empty workspace, or
    // nothing usable: the pill then shows just its number). Windows are
    // considered last-focused first (Hyprland's own `lastwindow`), then in
    // workspace order; the first rule that yields a name wins:
    //
    //   1. A Claude session hosted by a window here → the session's title
    //      (the same title the island shows). The host is found by process
    //      ancestry: the session's `claude` pid descends from the window's pid.
    //      One Claude app window can host several sessions; the one whose
    //      latest turn began most recently is taken as the one on screen.
    //      A terminal process can own many windows, so for a terminal the
    //      session also has to appear in that window's title.
    //   2. A project inferable from a terminal or editor title → its folder
    //      name (terminal: the last path-like token's basename, "~" excluded;
    //      VS Code family: the folder segment before the app name).
    //   3. The dominant app (most windows; ties go to the last-focused one)
    //      → its desktop-entry name.
    //
    // Every result is trimmed to `maxLen` characters with an ellipsis.
    function derive(ws) {
        const wins = root.leadFirst(ws);
        if (wins.length === 0)
            return null;
        var i, t, id, s;
        // 1. Claude session
        for (i = 0; i < wins.length; i++) {
            t = wins[i];
            id = root.appIdOf(t);
            const hosted = root.sessionsHostedBy(t.lastIpcObject?.pid ?? 0);
            if (hosted.length === 0)
                continue;
            s = root.isTerminal(id) ? root.sessionInTitle(hosted, t.title ?? "") : root.latestTurn(hosted);
            if (s)
                return root.entry(s.name, t, id);
        }
        // 2. project from a terminal / editor title
        for (i = 0; i < wins.length; i++) {
            t = wins[i];
            id = root.appIdOf(t);
            var p = "";
            if (root.isTerminal(id))
                p = root.projectFromTerminal(t.title ?? "");
            else if (root.isEditor(id))
                p = root.projectFromEditor(id, t.title ?? "");
            if (p !== "")
                return root.entry(p, t, id);
        }
        // 3. dominant app
        var counts = {};
        var best = null, bestN = 0;
        for (i = 0; i < wins.length; i++) {
            id = root.appIdOf(wins[i]);
            if (id === "")
                continue;
            counts[id] = (counts[id] ?? 0) + 1;
            if (counts[id] > bestN) {
                bestN = counts[id];
                best = wins[i];
            }
        }
        if (!best)
            return null;
        const name = root.appName(root.appIdOf(best));
        return name === "" ? null : root.entry(name, best, root.appIdOf(best));
    }

    // ---- helpers for the rule -------------------------------------------

    function entry(text, t, appId) {
        const full = (text || "").replace(/\s+/g, " ").trim();
        return {
            label: root.shorten(full),
            full: full,
            addr: String(t.address ?? "").replace(/^0x/, ""),
            appId: appId
        };
    }
    function shorten(s) {
        if (s.length <= root.maxLen)
            return s;
        // (no String.trimEnd in Qt's JS engine)
        return s.slice(0, root.maxLen - 1).replace(/\s+$/, "") + "…";
    }
    // Wayland appId is live; the IPC class is the fallback.
    function appIdOf(t) {
        return t?.wayland?.appId || t?.lastIpcObject?.class || "";
    }
    function isTerminal(id) {
        return root.terminalIds.indexOf(id.toLowerCase()) !== -1;
    }
    function isEditor(id) {
        return root.editorIds.indexOf(id.toLowerCase()) !== -1;
    }
    // The app's human name: its desktop entry, else the id's last segment.
    function appName(id) {
        if (!id)
            return "";
        const e = DesktopEntries.heuristicLookup(id);
        if (e && e.name)
            return e.name;
        const parts = id.split(".");
        return parts[parts.length - 1];
    }
    // The workspace's windows, Hyprland's `lastwindow` first.
    function leadFirst(ws) {
        const all = ws?.toplevels?.values ?? [];
        const lead = String(ws?.lastIpcObject?.lastwindow ?? "").replace(/^0x/, "");
        var first = [], rest = [];
        for (var i = 0; i < all.length; i++) {
            if (lead !== "" && String(all[i].address ?? "").replace(/^0x/, "") === lead)
                first.push(all[i]);
            else
                rest.push(all[i]);
        }
        return first.concat(rest);
    }
    // Live sessions (with a purposeful name) whose process descends from pid.
    function sessionsHostedBy(pid) {
        var out = [];
        if (!pid)
            return out;
        const live = Sessions.live;
        for (var i = 0; i < live.length; i++) {
            const anc = root._ancestry[String(live[i].pid)];
            if (anc && anc.indexOf(pid) !== -1 && root.genericSessionNames.indexOf(live[i].name.toLowerCase()) === -1)
                out.push(live[i]);
        }
        return out;
    }
    // When a session's latest turn began: now if busy (statusUpdatedAt is the
    // turn start), else the start we last saw, else its last status change.
    function turnStart(s) {
        if (s.status === "busy")
            return s.since;
        return root._lastTurn[String(s.pid)] ?? s.since;
    }
    function latestTurn(list) {
        var best = null;
        for (var i = 0; i < list.length; i++)
            if (!best || root.turnStart(list[i]) > root.turnStart(best))
                best = list[i];
        return best;
    }
    function sessionInTitle(list, title) {
        const t = title.toLowerCase();
        for (var i = 0; i < list.length; i++)
            if (t.indexOf(list[i].name.toLowerCase()) !== -1)
                return list[i];
        return null;
    }
    // Basename of the last path-like token ("~/.c/claudeos" → "claudeos").
    function projectFromTerminal(title) {
        const toks = title.trim().split(/\s+/);
        for (var i = toks.length - 1; i >= 0; i--) {
            const k = toks[i];
            if (k.charAt(0) !== "~" && k.indexOf("/") === -1)
                continue;
            const segs = k.replace(/\/+$/, "").split("/");
            const base = segs[segs.length - 1];
            return base === "~" ? "" : base;
        }
        return "";
    }
    // "● file.ts - folder - Visual Studio Code" → "folder". A lone file (no
    // folder open) names no project.
    function projectFromEditor(id, title) {
        var segs = title.replace(/^[●•*]\s*/, "").split(/\s+[-—–]\s+/);
        const app = root.appName(id).toLowerCase();
        const last = (segs[segs.length - 1] || "").toLowerCase();
        if (last === app || /visual studio code|vscodium|cursor/.test(last))
            segs.pop();
        return segs.length >= 2 ? segs[segs.length - 1].trim() : "";
    }

    // ActiveWindow.qml asks: would this title only repeat what the bar
    // already says (the app's own name, which the pill's icon shows, or the
    // focused workspace's label)?
    function redundantTitle(title, appId) {
        const t = (title || "").trim().toLowerCase();
        if (t === "" || t === root.appName(appId).toLowerCase())
            return true;
        const fw = Hyprland.focusedWorkspace;
        const e = fw ? root.labels[fw.id] : undefined;
        return !!e && e.full.toLowerCase() === t;
    }

    // ---- commit (with the settle rule from the header) ------------------

    function recompute() {
        if (!root._ready)
            return;
        const now = Date.now();
        const wss = Hyprland.workspaces?.values ?? [];
        var next = {}, pend = {};
        var changed = false;
        for (var i = 0; i < wss.length; i++) {
            const wid = wss[i].id;
            const d = root.derive(wss[i]);
            const cur = root.labels[wid];
            if (!d)
                continue;
            if (!cur || cur.addr !== d.addr) {
                next[wid] = d;
                changed = changed || !cur || cur.full !== d.full || cur.appId !== d.appId;
                continue;
            }
            next[wid] = cur;
            if (cur.full === d.full)
                continue;
            const p = root._pending[wid];
            if (p && p.full === d.full) {
                if (now - p.at >= root.settleMs) {
                    next[wid] = d;
                    changed = true;
                } else
                    pend[wid] = p;
            } else
                pend[wid] = {
                    full: d.full,
                    at: now
                };
        }
        for (const k in root.labels)
            if (next[k] === undefined)
                changed = true;
        root._pending = pend;
        if (changed)
            root.labels = next;
    }
    function schedule() {
        Qt.callLater(root.recompute);
    }

    // Pending texts get re-checked until they settle or fall away.
    Timer {
        interval: 500
        repeat: true
        running: Object.keys(root._pending).length > 0
        onTriggered: root.recompute()
    }

    Connections {
        target: Hyprland
        // Titles, opens/closes/moves, workspace churn: every event can move a
        // label, and recompute is a handful of comparisons. callLater runs it
        // after Quickshell has applied the event to its objects.
        function onRawEvent(event) {
            root.schedule();
        }
    }

    // Sessions.qml republishes `live` every poll (2.5 s): note turn starts,
    // re-probe ancestry only if the set of pids changed, then recompute.
    Connections {
        target: Sessions
        function onLiveChanged() {
            const live = Sessions.live;
            var turns = {}, pids = [];
            for (var i = 0; i < live.length; i++) {
                const key = String(live[i].pid);
                if (!/^[0-9]+$/.test(key))
                    continue;
                pids.push(key);
                turns[key] = live[i].status === "busy" ? live[i].since : root._lastTurn[key];
                if (turns[key] === undefined)
                    delete turns[key];
            }
            root._lastTurn = turns;
            const sig = pids.slice().sort().join(" ");
            if (sig !== root._pidSig) {
                root._pidSig = sig;
                root.probeLineage(pids);
            }
            root.schedule();
        }
    }

    // ---- process ancestry probe -----------------------------------------
    // "A <pid> <parent> <grandparent> …" per session, then "END". Pure sh
    // builtins reading /proc/<pid>/status; runs only when the pid set changes.
    property var _acc: ({})
    property var _queued: []
    function probeLineage(pids) {
        if (pids.length === 0) {
            root._ancestry = {};
            root._ready = true;
            return;
        }
        if (lineage.running) {
            root._queued = pids;
            root._rerun = true;
            return;
        }
        root._acc = {};
        lineage.command = ["sh", "-c", "for p; do case \"$p\" in *[!0-9]*|'') continue;; esac; printf 'A %s' \"$p\"; a=$p; n=0; while [ \"$n\" -lt 32 ]; do q=; while read -r k v; do if [ \"$k\" = PPid: ]; then q=$v; break; fi; done 2>/dev/null <\"/proc/$a/status\" || break; [ -n \"$q\" ] && [ \"$q\" -gt 1 ] || break; printf ' %s' \"$q\"; a=$q; n=$((n+1)); done; echo; done; echo END", "sh"].concat(pids);
        lineage.running = true;
    }
    Process {
        id: lineage
        stdout: SplitParser {
            onRead: line => {
                if (line === "END") {
                    root._ancestry = root._acc;
                    root._acc = {};
                    root._ready = true;
                    root.schedule();
                    return;
                }
                const parts = line.trim().split(" ");
                if (parts[0] !== "A" || parts.length < 2)
                    return;
                var anc = [];
                for (var i = 2; i < parts.length; i++) {
                    const n = parseInt(parts[i]);
                    if (n > 1)
                        anc.push(n);
                }
                root._acc[parts[1]] = anc;
            }
        }
        onRunningChanged: {
            if (running || !root._rerun)
                return;
            root._rerun = false;
            root.probeLineage(root._queued);
        }
    }

    Component.onCompleted: {
        // lastIpcObject (pid, class) is filled by an IPC read; ask for one.
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        root.schedule();
    }
}
