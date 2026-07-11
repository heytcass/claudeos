// CheatSheet.qml — a floating, Stylix-themed keybinding reference.
// Toggled by SUPER+H (Hyprland: `bind = $mod, H, global, quickshell:cheatsheet`).
// Grouped by task, one accent colour per group (base16), keys as keycap chips.
// NOTE: this is the human-facing mirror of the binds in home/hyprland.nix —
// keep the two in sync when binds change.
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

    // Three balanced columns of sections; each item is { keys: [...], desc }.
    readonly property var columns: [
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
                        keys: ["Super", "Shift", "M"],
                        desc: "Exit to login"
                    }
                ]
            },
            {
                title: "Claude",
                color: Theme.base0E,
                items: [
                    {
                        keys: ["Super", "C"],
                        desc: "Claude Code — coding & tasks"
                    },
                    {
                        keys: ["Super", "A"],
                        desc: "Ask — popup, answer as notification"
                    },
                    {
                        keys: ["Super", "Shift", "A"],
                        desc: "Screenshot analysis"
                    },
                    {
                        keys: ["Super", "Ctrl", "A"],
                        desc: "Screenshot → terminal follow-up"
                    }
                ]
            }
        ],
        [
            {
                title: "Focus",
                color: Theme.base0C,
                items: [
                    {
                        keys: ["Super", "← ↑ ↓ →"],
                        desc: "Move focus between windows"
                    }
                ]
            },
            {
                title: "Windows",
                color: Theme.base0B,
                items: [
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
                        keys: ["Super", "S"],
                        desc: "Scratchpad — toggle"
                    },
                    {
                        keys: ["Super", "Shift", "S"],
                        desc: "Stash window to scratchpad"
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
                    }
                ]
            },
            {
                title: "Help",
                color: Theme.base04,
                items: [
                    {
                        keys: ["Super", "H"],
                        desc: "This cheat sheet"
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
            width: content.implicitWidth + 52
            height: content.implicitHeight + 44
            radius: 16
            color: Theme.bg
            border.color: Theme.surface
            border.width: 1

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 20

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: "Keybindings"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "ClaudeOS · Hyprland"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                }

                // three columns of sections
                RowLayout {
                    spacing: 32
                    Repeater {
                        model: root.columns
                        delegate: ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 18

                            Repeater {
                                model: modelData   // this column's sections
                                delegate: ColumnLayout {
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 7

                                    // section header — coloured label + rule
                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            width: 3
                                            height: 14
                                            radius: 1.5
                                            color: modelData.color
                                        }
                                        Text {
                                            text: modelData.title
                                            color: modelData.color
                                            font.family: Theme.fontSans
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    // rows
                                    Repeater {
                                        model: modelData.items
                                        delegate: RowLayout {
                                            spacing: 10

                                            // keycap chips
                                            RowLayout {
                                                spacing: 4
                                                Repeater {
                                                    model: modelData.keys
                                                    delegate: Rectangle {
                                                        implicitWidth: kt.implicitWidth + 14
                                                        implicitHeight: kt.implicitHeight + 8
                                                        radius: 5
                                                        color: Theme.surface
                                                        border.color: Theme.muted
                                                        border.width: 1
                                                        Text {
                                                            id: kt
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: Theme.text
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: 12
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
}
