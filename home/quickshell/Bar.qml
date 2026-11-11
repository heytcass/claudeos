// Bar.qml — the ClaudeOS top bar, one PanelWindow per monitor.
// No longer a strip: the window is transparent and hosts three floating islands
// with wallpaper showing between them — left (workspace map: number + app
// icon per workspace · focused window title),
// center (the adaptive Island: the time and Claude), right (a quiet pill: the
// battery at rest, abnormal states and pending work surfacing on their own,
// the full set — media · mic · volume · network · bluetooth · tray · power —
// on hover).
// Colors/fonts/metrics from Theme.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    // Wayland idle-inhibit: while Caffeine holds (SUPER+I manual, or agent
    // activity), Hyprland's idle-notify stays quiet so hypridle never locks,
    // blanks, or suspends. The protocol needs a window surface — hence here
    // and not in the Caffeine singleton. One inhibitor per monitor's bar is
    // fine: the compositor refcounts them.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.inhibited
    }
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    // Float gap above/below the pills. The window is taller than a pill so the
    // islands hover clear of the screen edge; the exclusive zone reserves the
    // whole height, so tiled windows start below the floating bar. Same value
    // as the side margins: one 4px rhythm shared with Hyprland's gaps_out.
    readonly property int floatGap: Theme.edgeGap
    implicitHeight: (Theme.barHeight - 6) + floatGap * 2
    color: "transparent"

    // Tell the region tool where the three islands sit on this monitor, so it
    // can hover, click and snap to them (see BarRegions.qml).
    Component.onCompleted: BarRegions.register(modelData.name, [
        {
            label: "left",
            item: leftPill
        },
        {
            label: "island",
            item: island
        },
        {
            label: "right",
            item: rightPill
        }
    ])
    Component.onDestruction: BarRegions.unregister(modelData.name)

    // ---- left island ----
    Pill {
        id: leftPill
        entranceDelay: 0
        anchors.left: parent.left
        anchors.leftMargin: Theme.edgeGap
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: Theme.gap
            Workspaces {}
            ActiveWindow {
                Layout.maximumWidth: 440
            }
        }
    }

    // ---- center: the adaptive island (clock ⇄ agent ⇄ done) ----
    Island {
        id: island
        anchors.centerIn: parent
    }

    // The Shelf popup, opened by its hotkey (Shelf.popupOpen). It used to hang
    // off the island, which also took drag-to-shelve drops and a right-click;
    // both went with the island's slimming (2026-11), so shelving is the
    // hotkeys only now. The flag is global; only the focused monitor's bar
    // shows it.
    Connections {
        target: Shelf
        function onPopupOpenChanged() {
            shelfPopup.visible = Shelf.popupOpen && BarFocus.isFocused(bar);
        }
    }
    ShelfPopup {
        id: shelfPopup
        // one per bar, so pin it to this bar's monitor
        screen: bar.screen
        // Click-away (its HyprlandFocusGrab) hides the window directly; fold that back
        // into the flag so the next hotkey press opens rather than no-ops.
        onVisibleChanged: if (!visible)
            Shelf.popupOpen = false
    }

    // ---- right island: quiet by default ----
    // Silence is the normal state. At rest the pill holds only the battery;
    // every other widget sits in a PillSlot folded to zero width and speaks
    // only when its state is abnormal or something waits on you (rules
    // below, one per slot). Hovering the pill unfolds the full set — every
    // widget, popup and click action as before — and it folds back a short
    // grace after the pointer leaves, or after the last popup closes. Widths
    // ride the island's morph spring, so the pill breathes like the island.
    Pill {
        id: rightPill
        entranceDelay: 180
        anchors.right: parent.right
        anchors.rightMargin: Theme.edgeGap
        anchors.verticalCenter: parent.verticalCenter

        // Any widget popup open holds the pill unfolded, so a popup's anchor
        // never folds away underneath it.
        readonly property bool popupOpen: health.popupOpen || claude.popupOpen || media.popupOpen || network.popupOpen || bluetooth.popupOpen || power.popupOpen || battery.popupOpen
        readonly property bool held: hovered || popupOpen
        property bool expanded: false
        onHeldChanged: {
            if (held) {
                foldTimer.stop();
                expanded = true;
            } else {
                foldTimer.restart();
            }
        }
        Timer {
            id: foldTimer
            interval: 700
            onTriggered: rightPill.expanded = rightPill.held
        }

        // Probes land a beat after load (UPower reads 0, the sink is unbound,
        // nmcli hasn't answered): hold the abnormal rules off until then, so
        // the pill doesn't flash every widget open on startup.
        property bool settled: false
        Timer {
            interval: 2500
            running: true
            onTriggered: rightPill.settled = true
        }
        // Abnormal = expanded OR this. Each rule is the state worth a glance.
        function speaks(cond) {
            return expanded || (settled && cond);
        }

        // Battery: a plug-in / unplug briefly shows the percentage beside the
        // graphic, so the change is acknowledged without a click.
        property bool chargeFlash: false
        Connections {
            target: battery
            function onChargingChanged() {
                if (!rightPill.settled)
                    return;
                rightPill.chargeFlash = true;
                chargeFlashTimer.restart();
            }
        }
        Timer {
            id: chargeFlashTimer
            interval: 4000
            onTriggered: rightPill.chargeFlash = false
        }

        RowLayout {
            // Spacing lives in each slot's trailing gap, so folded slots
            // leave no stray space.
            spacing: 0

            // ---- pending work: always speaks when it has anything ----
            // These hide themselves when idle, so "always" costs nothing at
            // rest. The bar's conscience: a failed claudeos-* unit.
            PillSlot {
                shown: true
                HealthWidget {
                    id: health
                }
            }
            // The machine's inbox — agent-authored PRs waiting for review.
            PillSlot {
                shown: true
                ProposalsWidget {}
            }
            // Generated surfaces — a live card waiting to be looked at.
            PillSlot {
                shown: true
                CardsWidget {}
            }

            // ---- abnormal states ----
            // Caffeine: only a deliberate SUPER+I hold speaks. The agent's
            // auto-hold covers every Claude run (the island already says
            // Claude is busy), so it waits for hover.
            PillSlot {
                shown: rightPill.speaks(Caffeine.manual)
                CaffeineWidget {}
            }
            // Claude: an incident on status.claude.com, or a budget ≥90%
            // (the ring's warn band).
            PillSlot {
                shown: rightPill.speaks((claude.hasStatus && !claude.operational) || claude.maxPct >= 90)
                ClaudeWidget {
                    id: claude
                }
            }
            // Now playing: live while a player plays, so pausing stays one
            // click away. Leaves when playback stops.
            PillSlot {
                shown: rightPill.speaks(media.player !== null)
                MediaWidget {
                    id: media
                }
            }
            // Mic: speaks when muted.
            PillSlot {
                shown: rightPill.speaks(mic.muted)
                MicWidget {
                    id: mic
                }
            }
            // Volume: speaks when the output is muted, and while it is the
            // OSD (volume/brightness keys — it widens, then folds away).
            PillSlot {
                shown: rightPill.speaks(volume.muted || volume.osd)
                VolumeWidget {
                    id: volume
                }
            }
            // Network: offline, captive/limited, or a weak wifi link (the
            // bars' urgent band).
            PillSlot {
                shown: rightPill.speaks(!network.online || network.captive || (network.conType !== "ethernet" && network.signal >= 0 && network.signal < 40))
                NetworkWidget {
                    id: network
                }
            }
            // Bluetooth: a connected device running low.
            PillSlot {
                gap: 10
                shown: rightPill.speaks(bluetooth.lowBattery)
                BluetoothWidget {
                    id: bluetooth
                }
            }
            // Tray: an item asking for attention.
            PillSlot {
                gap: 10
                shown: rightPill.speaks(tray.attention)
                TrayWidget {
                    id: tray
                }
            }
            // Power menu — hover only, unless there is no battery to keep the
            // pill company (then it is the permanent glyph).
            PillSlot {
                shown: rightPill.speaks(!battery.visible)
                PowerWidget {
                    id: power
                }
            }

            // ---- permanent: the battery, rightmost so it never moves ----
            // Everything else unfolds leftward from it. Its percentage joins
            // it when low, on a plug/unplug, and on hover.
            PillSlot {
                gap: 2
                shown: rightPill.speaks(rightPill.chargeFlash || (!battery.charging && battery.pct <= 15))
                Text {
                    visible: battery.visible
                    text: battery.pct + "%"
                    color: battery.lvlColor
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSize - 2
                }
            }
            BatteryWidget {
                id: battery
            }
        }
    }
}
