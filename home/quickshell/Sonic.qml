pragma Singleton
// Sonic.qml — the sonic palette's player: decides WHEN an earcon may sound and
// plays it. The sounds themselves are synthesised at build time from the
// palette + motion tokens (lib/sonic.nix) and shipped beside this file as
// `sounds/`.
//
// One singleton, not per-island logic: Bar.qml makes an island per monitor,
// and each would otherwise play the same event once per screen.
//
// Moments:
//   · agent start/finish — an agent joining/leaving Agent.agents, debounced by Motion.quick so
//                          a flap never plays rise+fall back to back
//   · agent waiting      — the "hello" twinkle, via IPC from the Claude Code
//                          hook when a session is blocked on you
//   · notifications      — notify(urgency), called by Notifications.qml for
//                          the routes that reach a live surface (toast, peek)
//   · level ticks        — Osd.shown; pitch climbs with the level
//   · login chime        — once per login session, when the sink is ready
//
// Quiet rules (chosen 2026-10-27):
//   · media playing → silent, except the ticks (feedback you asked for)
//   · fullscreen window → silent, except Critical (which also punches through
//     visually) and the ticks. Quiet/ledger-routed notifications never call
//     notify() at all — that's the rest of the do-not-disturb story.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("sounds").toString().replace("file://", "")

    readonly property bool mediaPlaying: (Mpris.players?.values ?? []).some(p => p.playbackState === MprisPlaybackState.Playing)

    function play(name) {
        Quickshell.execDetached(["pw-play", "--media-role=Notification", root.dir + "/" + name + ".wav"]);
    }

    // ---- notifications ----
    function notify(urgency) {
        const critical = urgency === NotificationUrgency.Critical;
        if (root.mediaPlaying && !critical)
            return;
        if (Notifications.fullscreenActive && !critical)
            return;
        root.play(critical ? "notif-critical" : urgency === NotificationUrgency.Low ? "notif-low" : "notif-normal");
    }

    // ---- agent ----
    // Per agent, not per machine (chosen 2026-10-28): with parallel Claude
    // sessions the machine is almost never idle, so whole-machine edges were
    // near-silent. Each id joining Agent.agents is a start, each leaving is a
    // finish — "a reply is ready" even while other sessions keep working.
    // `sounded` is the set we last made a sound for; the first poll only
    // seeds it, so a bar restart doesn't announce agents it never saw begin.
    property var sounded: null
    Connections {
        target: Agent
        function onAgentsChanged() {
            agentSettle.restart();
        }
    }
    Timer {
        id: agentSettle
        interval: Motion.quick
        onTriggered: {
            const now = Agent.agents;
            const before = root.sounded;
            root.sounded = now;
            if (before === null)
                return;
            // Both at once (one finishing as another starts): the finish is
            // the one that wants you, so it wins.
            const finished = before.some(id => !now.includes(id));
            const started = now.some(id => !before.includes(id));
            if ((finished || started) && !root.mediaPlaying && !Notifications.fullscreenActive)
                root.play(finished ? "agent-finish" : "agent-start");
        }
    }

    // "Blocked on you": the Claude Code hook calls `qs ipc call sonic waiting`
    // when a session asks a question or waits on a permission. Same quiet
    // rules as the rise and fall. One question can fire both of its triggers,
    // so repeats within a `breathe` are one twinkle.
    property double lastWaiting: 0
    IpcHandler {
        target: "sonic"
        function waiting(): void {
            const now = Date.now();
            if (now - root.lastWaiting < Motion.breathe)
                return;
            root.lastWaiting = now;
            if (!root.mediaPlaying && !Notifications.fullscreenActive)
                root.play("agent-waiting");
        }
    }

    // ---- level ticks ----
    // A held key fires faster than a tick lasts; one tick per Motion.instant.
    property double lastTick: 0
    Connections {
        target: Osd
        function onShown() {
            const now = Date.now();
            if (now - root.lastTick < Motion.instant)
                return;
            root.lastTick = now;
            root.play("tick-" + Math.round((Osd.muted ? 0 : Osd.level) * 10));
        }
    }

    // ---- login chime ----
    // Once per login session: the first bar of a session claims a marker in
    // XDG_RUNTIME_DIR (tmpfs, emptied at logout), so a bar restart never
    // chimes. It waits for the default sink, not a fixed delay — at boot the
    // bar can beat Pipewire up.
    //
    // The speaker volume is a hardware mixer and WirePlumber restores it at
    // login, often low enough (~12%, about -54 dB) to swallow the chime. The
    // WAV peaks at -6 dBFS, so the stream has no gain to make that up with;
    // instead the sink is lifted to `chimeFloor` for the chime and put back
    // when pw-play exits. Muted stays muted.
    readonly property real chimeFloor: 0.4
    property bool chimeClaimed: false
    property real chimeRestore: -1
    Process {
        running: true
        command: ["sh", "-c", 'mkdir "$XDG_RUNTIME_DIR/claudeos-login-chime"']
        onExited: code => root.chimeClaimed = code === 0
    }
    readonly property bool chimeReady: root.chimeClaimed && (Osd.sink?.ready ?? false) && !!Osd.sink.audio
    onChimeReadyChanged: if (root.chimeReady) Qt.callLater(root.chime)
    function chime() {
        root.chimeClaimed = false;
        const a = Osd.sink.audio;
        if (a.muted)
            return;
        if (a.volume < root.chimeFloor) {
            root.chimeRestore = a.volume;
            Osd.hush = true;
            a.volume = root.chimeFloor;
        }
        chimeProc.running = true;
    }
    Process {
        id: chimeProc
        command: ["pw-play", "--media-role=Notification", root.dir + "/login.wav"]
        onExited: {
            const a = Osd.sink?.audio;
            // Only undo our own lift — if the volume moved meanwhile, it's the user's.
            if (a && root.chimeRestore >= 0 && Math.abs(a.volume - root.chimeFloor) < 0.01)
                a.volume = root.chimeRestore;
            root.chimeRestore = -1;
            unhush.restart();
        }
    }
    // The restore's volumeChanged lands asynchronously; let it pass first.
    Timer {
        id: unhush
        interval: Motion.standard
        onTriggered: Osd.hush = false
    }
}
