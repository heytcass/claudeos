// CardRenderer.qml — the pure schema→QML mapping for ONE card (Phase 4). Given a
// validated `card` object it renders each section with handwritten, Theme-styled
// components; it NEVER evaluates model output — the card is data, this is chrome.
// Section species (card.schema.json): text · kv · table · links · progress ·
// actions. Actions are a closed set — open / copy / dismiss / run — and `run`
// resolves ONLY through CardActions (generated from lib/card-actions.nix): a card
// can never name a command that isn't in the ring-1 registry, and nothing here
// evals a string. Every colour/metric comes from the Theme singleton.
import QtQuick
import QtQuick.Layouts
import Quickshell

Column {
    id: root
    property var card: ({})
    // NB: card arrives via Repeater.modelData, so card.sections is a QVariantList,
    // NOT a JS Array — Array.isArray() would return false and render nothing. A
    // QVariantList still has .length and iterates fine, so gate on truthiness only.
    readonly property var sections: (card && card.sections) ? card.sections : []
    readonly property color accent: (card && card.urgency === "critical") ? Theme.urgent : ((card && card.urgency === "low") ? Theme.muted : Theme.accent)
    spacing: 12

    // Pad/truncate each table row to the column count so the grid stays aligned
    // even if a row came a cell short.
    function tableCells(sec) {
        // .rows / .columns are QVariantLists (via modelData) — check length, not Array.isArray.
        if (!sec || sec.type !== "table" || !sec.rows || !sec.columns)
            return [];
        const n = sec.columns.length;
        var out = [];
        for (var r = 0; r < sec.rows.length; r++) {
            const row = sec.rows[r] || [];
            for (var c = 0; c < n; c++)
                out.push(row[c] !== undefined ? ("" + row[c]) : "");
        }
        return out;
    }

    // The closed action dispatch. Nothing here builds a command from card text.
    function runAction(a) {
        if (!a || !a.type)
            return;
        if (a.type === "open") {
            if (a.url)
                Quickshell.execDetached(["xdg-open", "" + a.url]);
        } else if (a.type === "copy") {
            if (a.text !== undefined)
                Quickshell.execDetached(["wl-copy", "--", "" + a.text]);
        } else if (a.type === "dismiss") {
            Cards.dismiss(root.card ? root.card.id : "");
        } else if (a.type === "run") {
            const argv = CardActions.commands[a.name];   // registry lookup — the ONLY source of a run command
            if (argv && argv.length)
                Quickshell.execDetached(argv);
        }
    }

    Repeater {
        model: root.sections
        delegate: Column {
            id: secBox
            required property var modelData
            width: root.width
            spacing: 6

            // ---- text ----
            Text {
                visible: secBox.modelData.type === "text"
                width: secBox.width
                text: secBox.modelData.type === "text" ? (secBox.modelData.text || "") : ""
                color: Theme.subtext
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.WordWrap
                lineHeight: 1.15
            }

            // ---- kv ----
            Column {
                visible: secBox.modelData.type === "kv"
                width: secBox.width
                spacing: 5
                Repeater {
                    model: secBox.modelData.type === "kv" ? secBox.modelData.rows : []
                    delegate: RowLayout {
                        required property var modelData
                        width: secBox.width
                        spacing: 10
                        Text {
                            Layout.preferredWidth: secBox.width * 0.38
                            text: modelData.label || ""
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.value || ""
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // ---- table ----
            GridLayout {
                visible: secBox.modelData.type === "table"
                width: secBox.width
                columns: secBox.modelData.type === "table" ? secBox.modelData.columns.length : 1
                columnSpacing: 12
                rowSpacing: 5
                // header
                Repeater {
                    model: secBox.modelData.type === "table" ? secBox.modelData.columns : []
                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData || ""
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 3
                        font.capitalization: Font.AllUppercase
                        elide: Text.ElideRight
                    }
                }
                // body cells (flattened, padded to the column count)
                Repeater {
                    model: root.tableCells(secBox.modelData)
                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData || ""
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }
            }

            // ---- links ----
            Flow {
                visible: secBox.modelData.type === "links"
                width: secBox.width
                spacing: 8
                Repeater {
                    model: secBox.modelData.type === "links" ? secBox.modelData.links : []
                    delegate: Rectangle {
                        required property var modelData
                        radius: 8
                        implicitWidth: lrow.implicitWidth + 18
                        implicitHeight: lrow.implicitHeight + 10
                        color: lhover.hovered ? Theme.surface : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                        HoverHandler {
                            id: lhover
                        }
                        Row {
                            id: lrow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↗"
                                color: root.accent
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label || modelData.url || ""
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        TapHandler {
                            onTapped: if (modelData.url)
                                Quickshell.execDetached(["xdg-open", "" + modelData.url])
                        }
                    }
                }
            }

            // ---- progress ----
            Column {
                visible: secBox.modelData.type === "progress"
                width: secBox.width
                spacing: 4
                Text {
                    visible: !!(secBox.modelData.type === "progress" && secBox.modelData.label)
                    text: secBox.modelData.type === "progress" ? (secBox.modelData.label || "") : ""
                    color: Theme.subtext
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }
                Rectangle {
                    width: secBox.width
                    height: 8
                    radius: 4
                    color: Theme.surface
                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: root.accent
                        // clamp the value into [0,1]
                        width: parent.width * Math.max(0, Math.min(1, secBox.modelData.type === "progress" ? (secBox.modelData.value || 0) : 0))
                    }
                }
            }

            // ---- actions ----
            Flow {
                visible: secBox.modelData.type === "actions"
                width: secBox.width
                spacing: 8
                Repeater {
                    model: secBox.modelData.type === "actions" ? secBox.modelData.actions : []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool primary: modelData.type === "open" || modelData.type === "run"
                        radius: 9
                        implicitWidth: arow.implicitWidth + 22
                        implicitHeight: arow.implicitHeight + 12
                        color: primary ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, ahover.hovered ? 0.28 : 0.16) : (ahover.hovered ? Theme.surface : "transparent")
                        border.width: 1
                        border.color: primary ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5) : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)
                        HoverHandler {
                            id: ahover
                        }
                        Row {
                            id: arow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label || modelData.type
                                color: primary ? Theme.text : Theme.subtext
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        TapHandler {
                            onTapped: root.runAction(modelData)
                        }
                    }
                }
            }
        }
    }
}
