pragma Singleton
// Sonic.qml — the sonic palette's player: decides WHEN an earcon may sound and
// plays it. The sounds themselves are synthesised at build time from the
// palette + motion tokens (lib/sonic.nix) and shipped beside this file as
// `sounds/`. The login chime is the one earcon not played here (the Hyprland
// start hook owns it, so restarting the bar never chimes).
//
// One singleton, not per-island logic: Bar.qml makes an island per monitor,
// and each would otherwise play the same event once per screen.
//
// Moments:
//   · agent start/finish — Agent.active edges, debounced by Motion.quick so
//                          a flap never plays rise+fall back to back
//   · notifications      — notify(urgency), called by Notifications.qml for
//                          the routes that reach a live surface (toast, peek)
//   · level ticks        — Osd.shown; pitch climbs with the level
//
// Quiet rules (chosen 2026-10-27):
//   · media playing → silent, except the ticks (feedback you asked for)
//   · fullscreen window → silent, except Critical (which also punches through
//     visually) and the ticks. Quiet/ledger-routed notifications never call
//     notify() at all — that's the rest of the do-not-disturb story.
import QtQuick
import Quickshell
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
    // `sounded` is the last state we made a sound for, seeded at load so the
    // bar starting mid-rebuild doesn't announce an agent it never saw begin.
    property bool sounded: Agent.active
    Connections {
        target: Agent
        function onActiveChanged() {
            agentSettle.restart();
        }
    }
    Timer {
        id: agentSettle
        interval: Motion.quick
        onTriggered: {
            if (Agent.active === root.sounded)
                return;
            root.sounded = Agent.active;
            if (!root.mediaPlaying && !Notifications.fullscreenActive)
                root.play(Agent.active ? "agent-start" : "agent-finish");
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
}
