pragma Singleton
// Osd.qml — the level the island's OSD face shows (volume, brightness).
//
// The media/brightness keys stay plain Hyprland exec binds (home/hyprland.nix)
// so they keep working with the bar dead or the session locked; this singleton
// only OBSERVES the result and asks every island to show it:
//
//   · volume     — the default sink's volume/mute, watched over Pipewire, so
//                  the keys, the VolumeWidget's scroll and any app that moves
//                  the sink all show the same feedback.
//   · brightness — the backlight has no change event (sysfs attributes don't
//                  inotify), so the bind follows brightnessctl with
//                  `qs ipc call osd brightness` and we read the level back.
//
// One singleton rather than per-island logic: an IpcHandler target must be
// unique, and Bar.qml instantiates an island per monitor.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // What to show: "volume" | "brightness", a 0..1 level, and mute.
    property string kind: ""
    property real level: 0
    property bool muted: false
    // Fired on every change, even a repeat of the same value (key held at
    // 100%), so each island restarts its hold timer.
    signal shown

    function show(k, l, m) {
        root.kind = k;
        root.level = Math.max(0, Math.min(1, l)); // PW allows >1; the bar is 0..1
        root.muted = m;
        root.shown();
    }

    // ---- volume ----
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
    // Binding a sink (startup, or the default device switching) reports its
    // initial volume as a change. Only changes after it settles are the user's.
    property bool armed: false
    onSinkChanged: {
        root.armed = false;
        armTimer.restart();
    }
    Timer {
        id: armTimer
        interval: 1000
        running: true
        onTriggered: root.armed = true
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            root.volumeMoved();
        }
        function onMutedChanged() {
            root.volumeMoved();
        }
    }
    // Set while Sonic lifts the sink for the login chime: a volume change that
    // is the system's, not the user's, shows no OSD (and plays no tick).
    property bool hush: false
    function volumeMoved() {
        if (root.armed && !root.hush && root.sink?.audio)
            root.show("volume", root.sink.audio.volume, root.sink.audio.muted);
    }

    // ---- brightness ----
    // `brightnessctl -m` → "intel_backlight,backlight,2250,30%,7500". A held
    // key fires faster than a read finishes, so a call mid-read sets `again`
    // and the read reruns once on exit — the last press is never dropped.
    property bool again: false
    Process {
        id: brightRead
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: line => {
                const pct = parseInt(line.split(",")[3]);
                if (!isNaN(pct))
                    root.show("brightness", pct / 100, false);
            }
        }
        onExited: if (root.again) {
            root.again = false;
            brightRead.running = true;
        }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void {
            if (brightRead.running)
                root.again = true;
            else
                brightRead.running = true;
        }
    }
}
