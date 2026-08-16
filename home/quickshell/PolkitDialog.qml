// PolkitDialog.qml — the polkit authentication agent, in the bar's process.
//
// Replaces soteria. The interesting part is not the UI, it is WHERE this runs.
//
// soteria had to be launched from Hyprland's exec-once, with its systemd user
// service deliberately disabled, because the user manager's environment lacks
// XDG_SESSION_ID at the point that unit would start — UWSM exports it too late,
// so soteria died with "Could not get XDG session id" and hit the start limit
// (see modules/desktop/hyprland.nix). Running the agent inside the already-
// running bar means there is no second process, no second unit, and no ordering
// problem to work around: by the time the bar exists, the session does.
//
// Colors/fonts come from Theme.qml — the same generated singleton the bar and
// the greeter read. Never hardcode hex (CLAUDE.md mandate).
//
// SECURITY NOTE: this is an auth prompt, so it deliberately does NOT dismiss on
// a backdrop click the way WishOverlay does — a stray click must not cancel an
// authorization the user meant to complete. Escape and the Cancel button are
// the explicit exits.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Scope {
    id: root

    PolkitAgent {
        id: agent
        // Clear any stale text the moment a NEW request arrives, so a password
        // typed for one action can never be submitted against another.
        onAuthenticationRequestStarted: {
            pw.text = "";
            pw.forceActiveFocus();
        }
    }

    readonly property var flow: agent.flow

    PanelWindow {
        id: win
        visible: agent.isActive
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        onVisibleChanged: if (visible)
            pw.forceActiveFocus()

        // Dim backdrop. No click-to-dismiss here — see the security note above.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.6)
            MouseArea {
                anchors.fill: parent
                // Swallow clicks so they cannot reach whatever is behind the
                // scrim, without treating a click as a cancel.
                onClicked: pw.forceActiveFocus()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: col.implicitHeight + 44
            radius: Theme.radius * 2
            color: Theme.bg
            border.width: 1
            border.color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)

            Keys.onEscapePressed: root.flow && root.flow.cancelAuthenticationRequest()

            Column {
                id: col
                anchors.centerIn: parent
                width: parent.width - 52
                spacing: 12

                // Title. A heading, so it takes the display face — the one
                // Poppins moment in this dialog (brand-guidelines: Poppins for
                // headings, Inter for chrome).
                Text {
                    width: parent.width
                    text: "Authentication required"
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize + 4
                    font.weight: Font.Medium
                }

                // What is being authorized. polkit's own message — chrome, so
                // Inter, and wrapped because these can be long.
                Text {
                    width: parent.width
                    text: root.flow ? root.flow.message : ""
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.WordWrap
                }

                // Which identity is authenticating. Shown only when there is a
                // real choice — on a single-user box polkit usually offers one,
                // and a picker with one entry is noise. Click to cycle.
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.radius
                    visible: root.flow && root.flow.identities && root.flow.identities.length > 1
                    color: idArea.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.7) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (!root.flow || !root.flow.selectedIdentity)
                                return "";
                            return root.flow.selectedIdentity.toString() + "  ⇄";
                        }
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: idArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const ids = root.flow.identities;
                            const i = ids.indexOf(root.flow.selectedIdentity);
                            root.flow.selectedIdentity = ids[(i + 1) % ids.length];
                        }
                    }
                }

                // The response field. polkit drives both the prompt text and
                // whether the response should echo — honour both rather than
                // assuming "password", so non-password factors stay usable.
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.radius
                    visible: root.flow ? root.flow.isResponseRequired : false
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
                    border.width: 1
                    // The card's single accent, and it marks state (focus) —
                    // matching how the bar spends accent everywhere else.
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
                        echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                        Keys.onEscapePressed: root.flow && root.flow.cancelAuthenticationRequest()
                        onAccepted: {
                            if (root.flow)
                                root.flow.submit(pw.text);
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pw.text.length === 0
                            text: (root.flow && root.flow.inputPrompt) ? root.flow.inputPrompt : "Password"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 1
                        }
                    }
                }

                // polkit's supplementary line — carries both "try again" style
                // errors and plain info, so its colour follows the flag rather
                // than assuming failure.
                Text {
                    width: parent.width
                    height: 15
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: (root.flow && root.flow.supplementaryIsError) ? Theme.urgent : Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Rectangle {
                        width: 96
                        height: 32
                        radius: Theme.radius
                        color: cancelArea.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize
                        }
                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.flow && root.flow.cancelAuthenticationRequest()
                        }
                    }

                    Rectangle {
                        width: 96
                        height: 32
                        radius: Theme.radius
                        color: okArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.9) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75)
                        Text {
                            anchors.centerIn: parent
                            text: "Authenticate"
                            color: Theme.bgAlt
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize
                        }
                        MouseArea {
                            id: okArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.flow && root.flow.submit(pw.text)
                        }
                    }
                }
            }
        }
    }
}
