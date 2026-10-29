// CheatSheet.qml — a floating, Stylix-themed keybinding reference.
// Toggled by SUPER+H (Hyprland: `bind = $mod, H, global, quickshell:cheatsheet`).
// Grouped by task, one accent colour per group (base16), keys as keycap chips:
// modifiers quiet, the key that changes row to row in the group's colour, and
// each column's descriptions aligned on one edge.
// NOTE: the Claude section is GENERATED (Keybinds.claude, from
// lib/keybindings.nix — edit there). The remaining sections hand-mirror the
// compositor binds and gestures in home/hyprland.nix — keep those in sync when
// binds change.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root
    property bool shown: false

    GlobalShortcut {
        appid: "quickshell"
        name: "cheatsheet"
        description: "Toggle the keybinding cheat sheet"
        onPressed: root.shown = !root.shown
    }

    // Chips drawn as modifiers (quiet) rather than as the row's key.
    readonly property var modifiers: ["Super", "Shift", "Ctrl", "3 fingers", "4 fingers"]

    // Three balanced columns of sections; each item is { keys: [...], desc }.
    readonly property var columns: [
        [
            {
                title: "Claude",
                color: Theme.base0E,
                // Generated from lib/keybindings.nix via the Keybinds.qml
                // singleton (home/hyprland.nix) — in sync by construction.
                items: Keybinds.claude
            }
        ],
        [
            {
                title: "Apps & Session",
                color: Theme.base0D,
                items: [
                    {
                        keys: ["Super", "Return"],
                        desc: "Terminal"
                    },
                    {
                        keys: ["Super", "Space"],
                        desc: "App launcher"
                    },
                    {
                        keys: ["Super", "Q"],
                        desc: "Close window"
                    },
                    {
                        keys: ["Super", "L"],
                        desc: "Lock screen"
                    },
                    {
                        keys: ["Super", "I"],
                        desc: "Caffeine — hold off idle/lock"
                    },
                    {
                        keys: ["Super", "Shift", "M"],
                        desc: "Exit to login"
                    }
                ]
            },
            {
                title: "Windows",
                color: Theme.base0B,
                items: [
                    {
                        keys: ["Super", "← ↑ ↓ →"],
                        desc: "Move focus"
                    },
                    {
                        keys: ["Super", "Shift", "← ↑ ↓ →"],
                        desc: "Move window in layout"
                    },
                    {
                        keys: ["Super", "Ctrl", "← ↑ ↓ →"],
                        desc: "Resize window"
                    },
                    {
                        keys: ["Super", "Drag"],
                        desc: "Move window (mouse)"
                    },
                    {
                        keys: ["Super", "Right-drag"],
                        desc: "Resize window (mouse)"
                    },
                    {
                        keys: ["Super", "V"],
                        desc: "Toggle floating"
                    },
                    {
                        keys: ["Super", "F"],
                        desc: "Fullscreen"
                    },
                    {
                        keys: ["Super", "P"],
                        desc: "Pseudo-tile"
                    }
                ]
            }
        ],
        [
            {
                title: "Workspaces",
                color: Theme.base0A,
                items: [
                    {
                        keys: ["Super", "1 – 5"],
                        desc: "Switch workspace"
                    },
                    {
                        keys: ["Super", "Shift", "1 – 5"],
                        desc: "Send window to workspace"
                    },
                    {
                        keys: ["Super", "Tab"],
                        desc: "Overview — drag windows between"
                    },
                    {
                        keys: ["Super", "O"],
                        desc: "Pin window as live mini-window"
                    }
                ]
            },
            {
                title: "Touchpad",
                color: Theme.base0C,
                items: [
                    {
                        keys: ["3 fingers", "← →"],
                        desc: "Swipe between workspaces"
                    },
                    {
                        keys: ["3 fingers", "↑"],
                        desc: "Toggle fullscreen"
                    },
                    {
                        keys: ["4 fingers", "↑"],
                        desc: "Overview"
                    }
                ]
            },
            {
                title: "Media & Display",
                color: Theme.base09,
                items: [
                    {
                        keys: ["Vol keys"],
                        desc: "Volume up / down / mute"
                    },
                    {
                        keys: ["Bright keys"],
                        desc: "Brightness up / down"
                    },
                    {
                        keys: ["Media keys"],
                        desc: "Play · pause · next · prev"
                    },
                    {
                        keys: ["Print"],
                        desc: "Region shot — copy · save · ask Claude"
                    },
                    {
                        keys: ["Shift", "Print"],
                        desc: "Full-screen shot to ~/Pictures"
                    }
                ]
            }
        ]
    ]

    PanelWindow {
        id: win
        visible: root.shown
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // dim backdrop — click anywhere to dismiss
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.base00.r, Theme.base00.g, Theme.base00.b, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }
        }

        // ESC to dismiss
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.shown = false
        }

        // the card
        Rectangle {
            anchors.centerIn: parent
            width: content.implicitWidth + 56
            height: content.implicitHeight + 48
            radius: Theme.radius * 2
            color: Theme.bgGlass
            border.color: Theme.surface
            border.width: 1

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 22

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Keybindings"
                        color: Theme.text
                        font.family: Theme.fontDisplay
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    // How to close it — replaces the old one-row Help section.
                    Chip {
                        label: "Super"
                        quiet: true
                    }
                    Chip {
                        label: "H"
                        quiet: true
                    }
                    Text {
                        text: "or"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                    }
                    Chip {
                        label: "Esc"
                        quiet: true
                    }
                    Text {
                        text: "to close"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface
                }

                // three columns of sections
                RowLayout {
                    spacing: 36
                    Repeater {
                        model: root.columns
                        delegate: ColumnLayout {
                            id: col
                            Layout.alignment: Qt.AlignTop
                            spacing: 20
                            // Widest chip row in this column: every row's chips
                            // take this width so the descriptions share one edge.
                            property real keyW: 0

                            Repeater {
                                model: modelData   // this column's sections
                                delegate: ColumnLayout {
                                    id: section
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 8
                                    readonly property color tint: modelData.color

                                    // section header — coloured bar + label
                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            implicitWidth: 3
                                            implicitHeight: 14
                                            radius: 1.5
                                            color: section.tint
                                        }
                                        Text {
                                            text: modelData.title
                                            color: section.tint
                                            font.family: Theme.fontSans
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    // rows
                                    Repeater {
                                        model: modelData.items
                                        delegate: RowLayout {
                                            spacing: 12

                                            Item {
                                                implicitWidth: col.keyW
                                                implicitHeight: chips.implicitHeight
                                                Row {
                                                    id: chips
                                                    spacing: 4
                                                    onImplicitWidthChanged: col.keyW = Math.max(col.keyW, implicitWidth)
                                                    Repeater {
                                                        model: modelData.keys
                                                        delegate: Chip {
                                                            label: modelData
                                                            quiet: root.modifiers.includes(modelData)
                                                            tint: section.tint
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.desc
                                                color: Theme.subtext
                                                font.family: Theme.fontSans
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A keycap. Quiet chips (modifiers) recede; the row's key carries the
    // section's colour so the eye lands on what differs between rows.
    component Chip: Rectangle {
        id: chip
        property string label
        property bool quiet: false
        property color tint: Theme.accent
        implicitWidth: kt.implicitWidth + 14
        implicitHeight: kt.implicitHeight + 8
        radius: Theme.radius / 2 + 1
        color: quiet ? Theme.surfaceGlass : Qt.rgba(tint.r, tint.g, tint.b, 0.14)
        border.width: 1
        border.color: quiet ? Theme.surface : Qt.rgba(tint.r, tint.g, tint.b, 0.55)
        Text {
            id: kt
            anchors.centerIn: parent
            text: chip.label
            color: chip.quiet ? Theme.subtext : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 12
        }
    }
}
