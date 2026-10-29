// ShelfPopup.qml — the working-memory Shelf, dropped down from the island
// (docs/plans/2026-10-28-working-memory-shelf.md, Phase 3). A grid of tiles for
// the active context's shelf, ungrouped first, then each group under a header.
//   · click        → open it (file/link) or copy it (text/image) — Shelf.open
//   · right-click  → actions below the grid: remove, note…, move to a context
//   · drag a tile  → out into another app, COPY ONLY: file items are kept by
//                    reference, and a Move would relocate the user's real file
//                    (Phase 0 spike). The finish result is unreliable under
//                    QtWayland, so the drag is fire-and-forget.
// Every write goes through the Shelf singleton → the claudeos-shelf CLI.
//
// A layer-shell PanelWindow, not a PopupWindow like CalendarPopup: a grabbing
// xdg_popup needs a recent input serial on its parent, so it refuses to open
// from the hotkey ("Failed to create grabbing popup"). Click-away comes from
// HyprlandFocusGrab instead, which needs no serial.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: popup
    anchors.top: true
    margins.top: 6
    exclusiveZone: 0
    focusable: true

    readonly property int tileSize: 93
    readonly property int maxBody: 460

    implicitWidth: 420
    implicitHeight: card.implicitHeight
    visible: false
    color: "transparent"

    // The item whose actions are showing (right-clicked), and whether the note
    // field is open for it.
    property string selectedId: ""
    property bool noting: false
    readonly property var selected: (Shelf.items || []).find(it => it.id === popup.selectedId) ?? null

    onVisibleChanged: {
        popup.selectedId = "";
        popup.noting = false;
        if (visible) {
            Shelf.refresh();
            keys.forceActiveFocus();
        }
    }
    // An item that vanished (removed, moved, tidied away) drops its selection.
    onSelectedChanged: if (!selected) {
        popup.selectedId = "";
        popup.noting = false;
    }

    // Where the selected item can go: every other saved context, plus "loose".
    readonly property var moveTargets: (Contexts.contexts || []).filter(c => c.slug !== Shelf.slug).concat(Shelf.slug === "_loose" ? [] : [{
                slug: "_loose",
                name: "loose"
            }])

    function host(url) {
        const m = (url || "").match(/^[a-z]+:\/\/([^\/?#]+)/i);
        return m ? m[1].replace(/^www\./, "") : url;
    }
    function basename(path) {
        return (path || "").split("/").pop();
    }

    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: popup.visible = false
    }

    // A small pill button, shared by the action row and the move chips.
    component Chip: Rectangle {
        id: chip
        property string label
        property color tone: Theme.text
        signal clicked
        implicitWidth: chipText.implicitWidth + 18
        implicitHeight: chipText.implicitHeight + 8
        radius: height / 2
        color: chipHover.hovered ? Theme.surface : "transparent"
        border.color: Qt.rgba(chip.tone.r, chip.tone.g, chip.tone.b, 0.4)
        border.width: 1
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.tone
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
        }
        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: chip.clicked()
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: {
            if (popup.selectedId !== "")
                popup.selectedId = "";
            else
                popup.visible = false;
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + 24
        color: Theme.bgGlass
        radius: 14
        border.color: Theme.surface
        border.width: 1

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            // ---- header: which shelf, how full ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Icons.shelf
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.iconSize
                }
                Text {
                    Layout.fillWidth: true
                    text: Shelf.displayName
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    text: Shelf.count === 1 ? "1 item" : Shelf.count + " items"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            // The last refusal, kept in place (the CLI also notified it).
            Text {
                Layout.fillWidth: true
                visible: Shelf.lastError !== ""
                text: Shelf.lastError
                color: Theme.warn
                wrapMode: Text.Wrap
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 1
            }

            // ---- empty state ----
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                visible: Shelf.count === 0
                text: "Nothing on this shelf yet. Drag something onto the island, or press Super+S to shelve the clipboard."
                color: Theme.muted
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 1
            }

            // ---- the tiles, scrolling past maxBody ----
            Flickable {
                id: scroller
                Layout.fillWidth: true
                visible: Shelf.count > 0
                Layout.preferredHeight: Math.min(sectionsCol.implicitHeight, popup.maxBody)
                contentHeight: sectionsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: sectionsCol
                    width: scroller.width
                    spacing: 10

                    Repeater {
                        model: Shelf.sections
                        delegate: Column {
                            id: section
                            required property var modelData
                            width: sectionsCol.width
                            spacing: 6

                            Text {
                                visible: section.modelData.title !== ""
                                text: section.modelData.title
                                color: Theme.subtext
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                            }

                            Flow {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    model: section.modelData.items
                                    delegate: Rectangle {
                                        id: tile
                                        required property var modelData
                                        readonly property var item: modelData
                                        readonly property var pay: item.payload || {}
                                        readonly property bool chosen: popup.selectedId === item.id

                                        width: popup.tileSize
                                        height: popup.tileSize
                                        radius: Theme.radius
                                        color: Theme.surfaceGlass
                                        border.width: 1
                                        border.color: tile.chosen ? Theme.accent : tileHover.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Theme.surface

                                        // image: the blob, cropped to fill and
                                        // masked to the tile's rounded corners
                                        // (same MultiEffect stencil as the
                                        // island's album art)
                                        Item {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            visible: tile.item.kind === "image"
                                            Image {
                                                id: thumb
                                                anchors.fill: parent
                                                source: parent.visible ? "file://" + Shelf.dir + "/" + tile.pay.blob : ""
                                                sourceSize.width: popup.tileSize * 2
                                                sourceSize.height: popup.tileSize * 2
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                                visible: false
                                            }
                                            Rectangle {
                                                id: thumbMask
                                                anchors.fill: parent
                                                radius: Theme.radius - 1
                                                visible: false
                                                layer.enabled: true
                                            }
                                            MultiEffect {
                                                anchors.fill: parent
                                                source: thumb
                                                maskEnabled: true
                                                maskSource: thumbMask
                                            }
                                        }

                                        // file / link / text: glyph + words
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            visible: tile.item.kind !== "image"
                                            spacing: 4

                                            Text {
                                                text: tile.item.kind === "file" ? Icons.file : tile.item.kind === "link" ? Icons.link : Icons.quote
                                                color: tile.item.missing ? Theme.warn : Theme.accent
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.iconSize
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: tile.item.kind === "file" ? popup.basename(tile.pay.path) : tile.item.kind === "link" ? popup.host(tile.pay.url) : (tile.pay.text || "")
                                                color: Theme.text
                                                wrapMode: tile.item.kind === "text" ? Text.Wrap : Text.WrapAnywhere
                                                maximumLineCount: tile.item.kind === "text" ? 4 : 3
                                                elide: Text.ElideRight
                                                font.family: Theme.fontSans
                                                font.pixelSize: Theme.fontSize - 2
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: !!tile.item.missing
                                                text: "moved or deleted"
                                                color: Theme.warn
                                                elide: Text.ElideRight
                                                font.family: Theme.fontSans
                                                font.pixelSize: Theme.fontSize - 3
                                                font.italic: true
                                            }
                                        }

                                        // the note, on a scrim along the bottom edge
                                        Rectangle {
                                            visible: !!tile.item.note
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 1
                                            height: noteText.implicitHeight + 6
                                            radius: Theme.radius - 1
                                            color: Theme.bgGlass
                                            Text {
                                                id: noteText
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                text: tile.item.note || ""
                                                color: Theme.subtext
                                                elide: Text.ElideRight
                                                font.family: Theme.fontSans
                                                font.pixelSize: Theme.fontSize - 3
                                                font.italic: true
                                            }
                                        }

                                        HoverHandler {
                                            id: tileHover
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            onTapped: Shelf.open(tile.item.id)
                                        }
                                        TapHandler {
                                            acceptedButtons: Qt.RightButton
                                            onTapped: {
                                                popup.noting = false;
                                                popup.selectedId = tile.chosen ? "" : tile.item.id;
                                            }
                                        }

                                        // ---- drag out (copy only) ----
                                        Drag.dragType: Drag.Automatic
                                        Drag.supportedActions: Qt.CopyAction
                                        Drag.proposedAction: Qt.CopyAction
                                        Drag.hotSpot.x: popup.tileSize / 4
                                        Drag.hotSpot.y: popup.tileSize / 4
                                        Drag.mimeData: {
                                            const k = tile.item.kind;
                                            if (k === "file")
                                                return {
                                                    "text/uri-list": "file://" + encodeURI(tile.pay.path) + "\r\n",
                                                    "text/plain": tile.pay.path
                                                };
                                            if (k === "image")
                                                return {
                                                    "text/uri-list": "file://" + encodeURI(Shelf.dir + "/" + tile.pay.blob) + "\r\n"
                                                };
                                            if (k === "link")
                                                return {
                                                    "text/uri-list": tile.pay.url + "\r\n",
                                                    "text/plain": tile.pay.url
                                                };
                                            return {
                                                "text/plain": tile.pay.text || ""
                                            };
                                        }
                                        DragHandler {
                                            target: null
                                            enabled: !tile.item.missing
                                            onActiveChanged: {
                                                if (active)
                                                    tile.grabToImage(r => {
                                                        tile.Drag.imageSource = r.url;
                                                        tile.Drag.active = true;
                                                    }, Qt.size(popup.tileSize / 2, popup.tileSize / 2));
                                                else
                                                    tile.Drag.active = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- actions for the right-clicked tile ----
            ColumnLayout {
                Layout.fillWidth: true
                visible: popup.selected !== null
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.surface
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Chip {
                        label: popup.selected?.note ? "Edit note" : "Note…"
                        onClicked: {
                            popup.noting = true;
                            noteInput.text = popup.selected?.note ?? "";
                            noteInput.forceActiveFocus();
                        }
                    }
                    Chip {
                        label: "Remove"
                        tone: Theme.urgent
                        onClicked: Shelf.remove(popup.selectedId)
                    }
                }

                // note field: Enter saves, an empty note clears it, Esc cancels
                Rectangle {
                    Layout.fillWidth: true
                    visible: popup.noting
                    implicitHeight: noteInput.implicitHeight + 12
                    radius: Theme.radius
                    color: Theme.surface
                    TextInput {
                        id: noteInput
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        color: Theme.text
                        selectionColor: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                        clip: true
                        onAccepted: {
                            Shelf.setNote(popup.selectedId, text.trim());
                            popup.noting = false;
                            keys.forceActiveFocus();
                        }
                        Keys.onEscapePressed: {
                            popup.noting = false;
                            keys.forceActiveFocus();
                        }
                    }
                }

                // move: every other saved context, plus "loose"
                Text {
                    visible: popup.moveTargets.length > 0
                    text: "Move to"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Flow {
                    visible: popup.moveTargets.length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: popup.moveTargets
                        delegate: Chip {
                            required property var modelData
                            label: modelData.name
                            tone: Theme.subtext
                            onClicked: Shelf.moveTo(popup.selectedId, modelData.slug)
                        }
                    }
                }
            }
        }
    }
}
