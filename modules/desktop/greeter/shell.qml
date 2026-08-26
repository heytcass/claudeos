// ClaudeOS greeter — the login screen, in the same QML the bar is written in.
//
// Runs as: greetd -> cage -s -d -- quickshell -p <this dir>/shell.qml
// as the `greeter` SYSTEM user, before any user session exists.
//
// DELIBERATELY ONE FILE. Quickshell registers a config dir as a single module,
// so any load error in any file makes every component "unavailable". In the bar
// that means "no bar"; here it means NO WAY TO LOG IN. Keeping the surface to
// one file plus two generated singletons (Theme.qml, GreeterConfig.qml) keeps
// that blast radius as small as it can be. Think hard before splitting this up.
//
// Colors/fonts come from Theme.qml — the SAME generator the bar uses
// (lib/quickshell-theme.nix), so the login screen matches the session by
// construction rather than by a second hand-maintained mapping. Never hardcode
// hex here (CLAUDE.md mandate).
//
// NOTE: FloatingWindow, not PanelWindow. cage is an xdg-shell kiosk and
// fullscreens the first toplevel; layer-shell is not something to rely on here.
// NOTE: no QtQuick.Controls anywhere in this repo — the password field is a
// bare TextInput, same idiom as WishOverlay.qml.

import QtQuick
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    FloatingWindow {
        id: win
        color: Theme.bgAlt

        // Auth state, all local to this window.
        property string prompt: ""
        property string status: ""
        property bool isError: false
        property bool echoResponse: false
        property bool busy: false
        property int sessionIndex: 0

        readonly property var session: GreeterConfig.sessions[win.sessionIndex]

        function resetSession() {
            win.busy = false;
            win.prompt = "";
            pw.text = "";
            Greetd.createSession(GreeterConfig.user);
        }

        // ---- background ------------------------------------------------
        // The Stylix wallpaper, same image the session and lock screen use.
        // (Measured 2026-08-15: this decodes in ~189ms even at 3840² on Kaby
        // Lake, so it is not the startup cost the greeter plan once suspected.)
        Image {
            anchors.fill: parent
            source: GreeterConfig.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        // Scrim, so the card stays legible over any wallpaper.
        Rectangle {
            anchors.fill: parent
            color: Theme.bgAlt
            opacity: 0.55
        }

        // ---- clock -----------------------------------------------------
        // Seconds precision on purpose: a ticking clock keeps the panel from
        // being a fully static image, which is belt-and-braces against the
        // Intel PSR freeze class of bug (fixed fleet-wide via i915.enable_psr=0
        // in modules/common/boot.nix, but cheap to not re-tempt).
        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        // ---- stage: the ONE screen the UI is centred on ------------------
        // cage fullscreens this single toplevel across the UNION of all
        // outputs, so `centerIn: parent` centres on the combined surface — with
        // two monitors that put the login card on the bezel (2026-08-25).
        // Everything the user reads lives inside this Item, which is pinned to
        // one screen's rectangle, so the children's centring is unchanged but
        // now means "centred on that screen".
        //
        // Coordinates: Quickshell.screens reports GLOBAL logical geometry, and
        // cage lays outputs out itself (its arrangement is NOT Hyprland's), so
        // never assume an origin — translate by the union's top-left corner,
        // which is (0,0) of this window.
        //
        // FALLBACK IS LOAD-BEARING: if screens are missing or a rect comes back
        // degenerate, fill the whole window. That is the old split-across-two
        // behavior, which is ugly but usable; a zero-sized stage would mean an
        // INVISIBLE LOGIN BOX, i.e. a lockout. Never let this collapse to 0.
        Item {
            id: stage

            // The built-in panel when it is on, else the first output. Chosen
            // for predictability: eDP-1 is present at every desk and is the
            // screen physically in front of Tom.
            readonly property var target: {
                var list = Quickshell.screens;
                if (!list || list.length === 0)
                    return null;
                for (var i = 0; i < list.length; i++) {
                    if (list[i].name === "eDP-1")
                        return list[i];
                }
                return list[0];
            }

            readonly property bool usable: target !== null && target.width > 0 && target.height > 0

            // Union origin — the global point this window's (0,0) sits at.
            readonly property real originX: {
                var list = Quickshell.screens;
                if (!list || list.length === 0)
                    return 0;
                var m = list[0].x;
                for (var i = 1; i < list.length; i++)
                    m = Math.min(m, list[i].x);
                return m;
            }
            readonly property real originY: {
                var list = Quickshell.screens;
                if (!list || list.length === 0)
                    return 0;
                var m = list[0].y;
                for (var i = 1; i < list.length; i++)
                    m = Math.min(m, list[i].y);
                return m;
            }

            x: usable ? target.x - originX : 0
            y: usable ? target.y - originY : 0
            width: usable ? target.width : win.width
            height: usable ? target.height : win.height
        }

        Column {
            anchors.horizontalCenter: stage.horizontalCenter
            anchors.top: stage.top
            anchors.topMargin: Math.round(stage.height * 0.16)
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "h:mm")
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 72
                font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: Theme.subtext
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize + 3
            }
        }

        // ---- login card ------------------------------------------------
        Rectangle {
            id: card
            anchors.centerIn: stage
            anchors.verticalCenterOffset: Math.round(stage.height * 0.12)
            width: 380
            height: cardCol.implicitHeight + 40
            radius: Theme.radius * 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

            Column {
                id: cardCol
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 14

                // Avatar: initial in a circle. No avatar file to read as the
                // greeter user, and a missing-image box would look broken.
                //
                // NEUTRAL fill, deliberately. This used to be a solid
                // Theme.accent disc, which spent the single strongest brand
                // signal on pure decoration — and put it in direct competition
                // with the focus ring below, which actually carries meaning
                // ("your keystrokes land here"). Brand rule: one accent per
                // view, and it goes to the thing that means something.
                // The initial itself takes the accent, which is enough to tie
                // the card to the palette without shouting.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)
                    border.width: 1
                    border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.5)
                    Text {
                        anchors.centerIn: parent
                        text: GreeterConfig.user.charAt(0).toUpperCase()
                        // Theme.text, NOT Theme.accent. Across 17 bar files the
                        // accent is only ever an active-STATE marker, always in
                        // a ternary against text/muted (`radioOn ? accent :
                        // muted`, `sameDay(today) ? accent : text`). It is never
                        // a static decorative fill. An avatar initial is
                        // identity, not state — so it takes text, and the focus
                        // ring below keeps the card's single accent.
                        color: Theme.text
                        // Display face: a single glyph at 26px is a display
                        // moment, not UI chrome.
                        font.family: Theme.fontDisplay
                        font.pixelSize: 26
                        font.weight: Font.Medium
                    }
                }

                // The one genuine DISPLAY line in the greeter — this is
                // identity, not chrome, so it takes Poppins. Everything else
                // here (prompt, session, status) is chrome and stays Inter;
                // the clock stays Inter too because a large standalone numeral
                // belongs to Inter, not the display face.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: GreeterConfig.user
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize + 5
                    font.weight: Font.Medium
                    // Poppins is geometric and set tight by default; a little
                    // tracking keeps a short lowercase name from reading as a
                    // logo lockup.
                    font.letterSpacing: 0.3
                }

                // Password / prompt field.
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.radius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
                    border.width: 1
                    border.color: pw.activeFocus ? Theme.accent : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                        clip: true
                        enabled: !win.busy
                        // greetd tells us per-prompt whether to echo. Honour it
                        // rather than assuming every prompt is a password —
                        // that is how 2FA/OTP prompts stay usable.
                        echoMode: win.echoResponse ? TextInput.Normal : TextInput.Password
                        onAccepted: {
                            if (win.busy)
                                return;
                            win.busy = true;
                            win.status = "";
                            Greetd.respond(pw.text);
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pw.text.length === 0
                            text: win.prompt !== "" ? win.prompt : "Password"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 1
                        }
                    }
                }

                // Session picker. Click to cycle. The plain "Hyprland" entry is
                // NOT offered at all — it never activates graphical-session
                // .target, stranding hyprpaper/hypridle/gammastep (no wallpaper,
                // no idle-lock, no night light). regreet listed it and the only
                // defence was remembering not to pick it; here the footgun is
                // removed by construction. See GreeterConfig.qml.
                Rectangle {
                    width: parent.width
                    height: 30
                    radius: Theme.radius
                    color: sessArea.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.7) : "transparent"
                    visible: GreeterConfig.sessions.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: GreeterConfig.sessions.length > 1 ? win.session.name + "  ⇄" : win.session.name
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: sessArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: GreeterConfig.sessions.length > 1
                        onClicked: win.sessionIndex = (win.sessionIndex + 1) % GreeterConfig.sessions.length
                    }
                }

                // Status / error line. Reserves its height so the card doesn't
                // jump when a message appears.
                Text {
                    width: parent.width
                    height: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: win.busy && win.status === "" ? "Authenticating…" : win.status
                    color: win.isError ? Theme.urgent : Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }
            }
        }

        // ---- greetd wiring ---------------------------------------------
        Connections {
            target: Greetd

            function onAuthMessage(message, error, responseRequired, echoResponse) {
                win.echoResponse = echoResponse;
                win.isError = error;
                if (responseRequired) {
                    win.prompt = message;
                    win.busy = false;
                    pw.text = "";
                    pw.forceActiveFocus();
                } else {
                    // Informational only (e.g. "Password expired") — show it and
                    // let greetd drive the next step.
                    win.status = message;
                }
            }

            function onAuthFailure(message) {
                win.isError = true;
                win.status = message !== "" ? message : "Authentication failed";
                win.resetSession();
                pw.forceActiveFocus();
            }

            function onReadyToLaunch() {
                win.busy = true;
                win.status = "Starting session…";
                Greetd.launch(win.session.command);
            }

            function onError(error) {
                win.isError = true;
                win.status = error;
                win.busy = false;
            }
        }

        Component.onCompleted: {
            pw.forceActiveFocus();
            if (Greetd.available) {
                Greetd.createSession(GreeterConfig.user);
            } else {
                // Reached when previewing with `qs -p` outside a greetd socket
                // (that is how this file is load-checked before deploying).
                // Say so plainly instead of sitting on a dead prompt.
                win.status = "preview — no greetd socket";
            }
        }
    }
}
