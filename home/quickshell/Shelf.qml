pragma Singleton
// The pragma must stay on line 1, above every comment (see Contexts.qml: the
// singleton scan stops at the first opening brace, even inside a comment).
// Shelf.qml — the working-memory Shelf model for the bar
// (docs/plans/2026-10-28-working-memory-shelf.md, Phase 3). It reads
// `claudeos-shelf list` for the active context's shelf and sends every write
// (add / rm / note / move / open) through the CLI, which is the only writer:
// the bar never touches shelf.json itself, so validation, caps and the
// context-repo commit stay in one place.
//
// Polled like Contexts.qml (a lazy 10s cadence, since writes from the hotkeys
// happen outside the bar), plus an immediate re-read whenever the focused
// workspace changes (that's how the active shelf changes) and after every write
// the bar itself makes. No model calls.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    // --- the shelf on screen (the last `list` result) -------------------------
    property var items: []
    property var groups: []
    property string slug: "_loose"
    property string name: "_loose"
    property string dir: ""
    readonly property int count: items.length
    readonly property string displayName: slug === "_loose" ? "loose" : name

    // Where a drop or hotkey lands RIGHT NOW. Reactive (it rides Contexts'
    // focused-workspace binding), so the drop face never shows a stale name
    // between polls. The CLI derives the same target on its own.
    readonly property string targetName: Contexts.activeName || "loose"

    // The popup's open state lives here so the hotkey (a singleton-owned
    // GlobalShortcut) and the Island's right-click drive one flag.
    property bool popupOpen: false

    // The last CLI refusal (caps, a moved file…), for the popup to show. The
    // CLI already notifies; this just keeps the reason visible in place.
    property string lastError: ""

    // Fired after an `add` the bar made succeeds, so the Island can flash
    // "Shelved" and play its earcon only on a real success (addFailed otherwise —
    // the CLI has already notified the reason).
    signal shelved(string target)
    signal addFailed(string reason)

    // Group the items for the popup: ungrouped first, then each group in the
    // shelf's own `groups` order, then any group the order doesn't name.
    // [{title, items}] — title "" for the ungrouped run.
    readonly property var sections: {
        const its = items || [];
        const order = (groups || []).slice();
        for (const it of its)
            if (it.group && order.indexOf(it.group) < 0)
                order.push(it.group);
        const out = [];
        const loose = its.filter(it => !it.group);
        if (loose.length)
            out.push({
                title: "",
                items: loose
            });
        for (const g of order) {
            const inG = its.filter(it => it.group === g);
            if (inG.length)
                out.push({
                    title: g,
                    items: inG
                });
        }
        return out;
    }

    // --- reads ----------------------------------------------------------------
    property bool _again: false
    function refresh() {
        if (lister.running)
            root._again = true;
        else
            lister.running = true;
    }

    Process {
        id: lister
        command: ["claudeos-shelf", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(this.text);
                    root.items = s.items || [];
                    root.groups = s.groups || [];
                    root.slug = s.slug || "_loose";
                    root.name = s.name || root.slug;
                    root.dir = s.dir || "";
                } catch (e) {
                // A failed list (CLI missing mid-rebuild, a lock timeout) keeps
                // the last good view; the next poll settles it.
                }
            }
        }
        onExited: {
            if (root._again) {
                root._again = false;
                running = true;
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Contexts
        function onFocusedWsNameChanged() {
            root.refresh();
        }
    }

    // --- writes ---------------------------------------------------------------
    // One Process, a FIFO queue: the CLI serialises writers with flock anyway,
    // but queueing here keeps each exit code paired with its own command.
    property var _queue: []
    function _run(args, kind) {
        root._queue.push({
            args: args,
            kind: kind || ""
        });
        root._pump();
    }
    function _pump() {
        if (writer.running || root._queue.length === 0)
            return;
        const job = root._queue.shift();
        writer.kind = job.kind;
        writer.command = job.args;
        writer.running = true;
    }

    Process {
        id: writer
        property string kind: ""
        stderr: StdioCollector {
            id: writerErr
        }
        onExited: code => {
            if (code === 0) {
                root.lastError = "";
                if (kind === "add")
                    root.shelved(root.targetName);
            } else {
                // "claudeos-shelf: <reason>" — keep only the reason.
                const msg = writerErr.text.trim().split("\n").pop() || "";
                root.lastError = msg.replace(/^claudeos-shelf:\s*/, "");
                if (kind === "add")
                    root.addFailed(root.lastError);
            }
            root.refresh();
            root._pump();
        }
    }

    // Best-effort provenance: the window that had focus when the drag started
    // is (almost always) the one it came from. Structured fields only.
    function _sourceJson() {
        const t = ToplevelManager.activeToplevel;
        if (!t)
            return [];
        const src = {};
        if (t.appId)
            src["class"] = t.appId;
        if (t.title)
            src.title = t.title;
        return Object.keys(src).length ? ["--source-json", JSON.stringify(src)] : [];
    }

    // kind: file | image | text | link. `arg` is the path / url / text itself
    // (text goes in argv, not stdin, so a Process needs no stdin plumbing).
    function add(kind, arg) {
        root._run(["claudeos-shelf", "add", kind, arg].concat(root._sourceJson()), "add");
    }
    function remove(id) {
        root._run(["claudeos-shelf", "rm", id]);
    }
    function setNote(id, text) {
        root._run(["claudeos-shelf", "note", id, text]);
    }
    function moveTo(id, context) {
        root._run(["claudeos-shelf", "move", id, context]);
    }
    function open(id) {
        root._run(["claudeos-shelf", "open", id]);
    }

    // --- image bytes from a drop ------------------------------------------------
    // A dragged image arrives as raw bytes (the spike: Chrome offers
    // application/octet-stream;name="x.avif"). Stage them in XDG_RUNTIME_DIR
    // (tmpfs, per-user), `add image` the file, then delete the staging copy —
    // the CLI has already copied it into the shelf's blobs/ by then.
    property var _pendingImage: null
    function addImageBytes(buffer, ext) {
        if (root._pendingImage)
            return; // one staged image at a time; a second rapid drop is dropped
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        root._pendingImage = {
            path: runtime + "/claudeos-shelf-drop-" + Date.now() + "." + ext,
            source: root._sourceJson()
        };
        stager.path = root._pendingImage.path;
        stager.setData(buffer);
    }

    FileView {
        id: stager
        onSaved: {
            const p = root._pendingImage;
            root._pendingImage = null;
            if (!p)
                return;
            root._run(["sh", "-c", "claudeos-shelf add image \"$@\"; rc=$?; rm -f -- \"$1\"; exit $rc", "sh", p.path].concat(p.source), "add");
        }
        onSaveFailed: err => {
            root._pendingImage = null;
            root.lastError = "couldn't stage the dropped image";
            root.addFailed(root.lastError);
        }
    }

    // --- the hotkey (lib/keybindings.nix: Super+Ctrl+S → quickshell:shelf) ---
    GlobalShortcut {
        appid: "quickshell"
        name: "shelf"
        description: "Open the shelf for the current context"
        onPressed: root.popupOpen = !root.popupOpen
    }

    // Scriptable too: `qs ipc call shelf toggle` (tests, other tools).
    IpcHandler {
        target: "shelf"
        function toggle(): void {
            root.popupOpen = !root.popupOpen;
        }
        function refresh(): void {
            root.refresh();
        }
    }
}
