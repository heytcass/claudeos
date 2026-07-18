// CardSurface.qml — where generated surfaces live (Phase 4). A dropdown-style
// overlay (same layer-shell pattern as PresencePanel) listing every live card,
// each rendered by CardRenderer from validated data. Opened by the CardsWidget
// bar glyph or the island (both flip Cards.surfaceOpen); Esc or click-away
// dismisses the surface, and it auto-closes when the last card is gone. Cards
// themselves never interrupt — this is their home, always waiting, never a toast.
import QtQuick
import Quickshell

Scope {
    id: root

    // When the last card is dismissed, fold the (now empty) surface away.
    Connections {
        target: Cards
        function onCountChanged() {
            if (Cards.count === 0)
                Cards.surfaceOpen = false;
        }
    }

    PanelWindow {
        id: win
        visible: Cards.surfaceOpen
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // click-away + Esc dismiss
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Cards.surfaceOpen = false
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Cards.surfaceOpen = false
        }

        // The stack of cards, dropping just below the floating bar, centered and
        // scrollable when it outgrows ~70% of the screen.
        Flickable {
            id: flick
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight + Theme.edgeGap * 2 + 6
            width: 460
            // Cap at 70% of the screen; `parent.height` is the window content
            // size (the PanelWindow object's own `height` is 0 for an
            // anchored-all-sides window, which would collapse the Flickable).
            height: Math.min(stack.implicitHeight, parent.height * 0.7)
            contentWidth: width
            contentHeight: stack.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // swallow clicks inside the stack so they don't hit the dismiss scrim
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {}
            }

            Column {
                id: stack
                width: flick.width
                spacing: 12

                Repeater {
                    model: Cards.cards
                    delegate: Rectangle {
                        required property var modelData
                        width: stack.width
                        implicitHeight: body.implicitHeight + 28
                        radius: 16
                        color: Theme.bg
                        border.width: 1
                        readonly property color accent: modelData.urgency === "critical" ? Theme.urgent : (modelData.urgency === "low" ? Theme.muted : Theme.accent)
                        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.45)

                        Column {
                            id: body
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 12

                            // header: icon + title + dismiss
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(titleRow.implicitHeight, 20)
                                Row {
                                    id: titleRow
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: closeBtn.left
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !!modelData.icon
                                        text: modelData.icon || ""
                                        font.pixelSize: Theme.fontSize + 3
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, titleRow.width - 30)
                                        text: modelData.title || ""
                                        color: Theme.text
                                        font.family: Theme.fontSans
                                        font.bold: true
                                        font.pixelSize: Theme.fontSize
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    id: closeBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    color: closeHover.hovered ? Theme.text : Theme.muted
                                    font.pixelSize: Theme.fontSize
                                    HoverHandler {
                                        id: closeHover
                                    }
                                    TapHandler {
                                        onTapped: Cards.dismiss(modelData.id)
                                    }
                                }
                            }

                            // the sections, rendered from data
                            CardRenderer {
                                width: body.width
                                card: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
