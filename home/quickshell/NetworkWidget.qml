// NetworkWidget.qml — drawn signal-strength bars (wifi) or a plug glyph
// (ethernet), tinted by strength, polled from nmcli every 5s. The SSID/percent
// stay out of the strip — the bars say "connected + how strong" at a glance;
// hover for the name. For wifi the lit-bar count and colour both track signal.
//
// Why nmcli and not `Quickshell.Networking` (which exists as of 0.3.0, unlike
// when this file was first written): its `Network` type carries name/connected/
// known/state and connect()/disconnect()/forget(), and `Networking.wifiEnabled`
// is writable — but it exposes **no signal strength and no security flag**, and
// those two drive the entire visual language here (bar count, tint, lock glyph)
// plus the decision of whether to prompt for a passphrase. Revisit if upstream
// adds them; the radio toggle and connect flow would port over cleanly.
//
// Click for the popup: tap the header to toggle the radio, tap a network to
// join it (secured networks you have never joined reveal a passphrase field),
// and the footer rescans or opens nm-connection-editor for the awkward cases.
//
// The widget deliberately stays visible with nothing connected. It used to
// hide on `conName === ""`, which meant it vanished at exactly the moment it
// was needed — 2026-08-07 that left no way at all to pick a network after an
// undock, and the only reachable tool (nm-connection-editor) cannot scan.
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property string conName: ""
    property string conType: ""
    property int signal: -1
    property bool radioOn: true

    // Scan results: [{ ssid, signal, security, inUse }], strongest per SSID.
    property var networks: []
    // SSIDs we already hold a saved profile for — those need no passphrase.
    property var savedSsids: []
    property bool scanning: false
    // Non-empty while a secured, unknown SSID is waiting on its passphrase.
    property string pendingSsid: ""
    property string status: ""

    implicitWidth: content.width + 12
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radius
    color: "transparent"

    readonly property bool online: conName !== ""
    // Strength → semantic colour.
    readonly property color strength: signal >= 70 ? Theme.good : (signal >= 40 ? Theme.warn : Theme.urgent)

    // nmcli -t escapes ':' as '\:' and '\' as '\\'. Split on unescaped colons
    // only — SSIDs legitimately contain colons, and a naive split() silently
    // truncates those names.
    function parseFields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function refreshAll() {
        conProc.running = true;
        sigProc.running = true;
        radioProc.running = true;
        savedProc.running = true;
    }

    // force = ask the card for a fresh sweep rather than NM's cache.
    function scan(force) {
        if (!root.radioOn)
            return;
        root.scanning = true;
        scanProc.command = ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list" + (force ? " --rescan yes" : "")];
        scanProc.running = true;
    }

    // On = clear the soft block first, then enable: a block set outside NM
    // (see modules/common/networking.nix) survives `radio wifi on` alone.
    // Off is user-initiated here, so the persisted block it leaves behind is
    // intended — wifi-undock-reconcile will lift it on the next undock/boot.
    function setRadio(on) {
        if (on) {
            Quickshell.execDetached(["rfkill", "unblock", "wlan"]);
            Quickshell.execDetached(["nmcli", "radio", "wifi", "on"]);
        } else {
            Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
        }
        root.networks = [];
        radioTick.restart();
    }

    function join(ssid, security) {
        if (security !== "" && root.savedSsids.indexOf(ssid) < 0) {
            root.status = "";
            root.pendingSsid = ssid;
            return;
        }
        root.doConnect(ssid, "");
    }

    function doConnect(ssid, pw) {
        root.status = "connecting to " + ssid + "…";
        connProc.command = pw === "" ? ["nmcli", "device", "wifi", "connect", ssid] : ["nmcli", "device", "wifi", "connect", ssid, "password", pw];
        connProc.running = true;
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: root.conType === "ethernet" ? eth.implicitWidth : (root.online ? bars.width : off.implicitWidth)
        height: parent.height

        // ---- wifi: four rising bars, lit up to signal ----
        Row {
            id: bars
            anchors.verticalCenter: parent.verticalCenter
            visible: root.online && root.conType !== "ethernet"
            spacing: 2
            // thresholds each bar lights at
            readonly property var cut: [12, 38, 62, 82]
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 4 + index * 3
                    radius: 1.5
                    anchors.bottom: parent.bottom
                    readonly property bool lit: root.signal >= bars.cut[index]
                    color: lit ? root.strength : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.35)
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }
                }
            }
        }

        // ---- ethernet: plug glyph ----
        Text {
            id: eth
            anchors.centerIn: parent
            visible: root.online && root.conType === "ethernet"
            text: Icons.ethernet
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: Theme.good
        }

        // ---- nothing connected: muted wifi glyph, still clickable ----
        Text {
            id: off
            anchors.centerIn: parent
            visible: !root.online
            text: Icons.wifi
            font.family: Theme.fontMono
            font.pixelSize: Theme.iconSize
            color: Theme.muted
        }
    }

    HoverHandler {
        id: hover
    }
    TapHandler {
        onTapped: {
            popup.visible = !popup.visible;
            if (popup.visible) {
                root.status = "";
                root.pendingSsid = "";
                root.refreshAll();
                root.scan(true);
            }
        }
    }

    // Hover reveals the connection name (+ signal for wifi) — suppressed once
    // the popup is open, which already says everything the tooltip would.
    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        implicitWidth: nameText.implicitWidth + 20
        implicitHeight: 30
        visible: hover.hovered && !popup.visible
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 8
            border.color: Theme.surface
            border.width: 1
            Text {
                id: nameText
                anchors.centerIn: parent
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 12
                text: !root.online ? (root.radioOn ? "offline — tap to pick a network" : "wifi off — tap to turn on") : root.conType === "wifi" && root.signal >= 0 ? root.conName + "  ·  " + root.signal + "%" : root.conName
            }
        }
    }

    // ---- the picker ----
    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
        implicitWidth: 300
        implicitHeight: col.implicitHeight + 22
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 10
            border.color: Theme.surface
            border.width: 1

            Column {
                id: col
                anchors.centerIn: parent
                width: parent.width - 28
                spacing: 6

                // header: radio state + toggle
                Row {
                    spacing: 8
                    Text {
                        text: Icons.wifi
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize
                        color: root.radioOn ? Theme.accent : Theme.muted
                    }
                    Text {
                        text: root.radioOn ? "on — tap to turn off" : "off — tap to turn on"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                    TapHandler {
                        onTapped: root.setRadio(!root.radioOn)
                    }
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                }

                // scanned networks: tap to join
                Repeater {
                    model: root.networks
                    delegate: Item {
                        required property var modelData
                        width: col.width
                        height: 22

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 7
                            radius: 3.5
                            color: modelData.inUse ? Theme.good : modelData.signal >= 70 ? Theme.text : modelData.signal >= 40 ? Theme.subtext : Theme.muted
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            anchors.right: meta.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData.ssid
                            color: modelData.inUse ? Theme.text : Theme.subtext
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Row {
                            id: meta
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                visible: modelData.security !== ""
                                text: Icons.lock
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSize - 3
                                color: root.savedSsids.indexOf(modelData.ssid) >= 0 ? Theme.subtext : Theme.muted
                            }
                            Text {
                                text: modelData.signal + "%"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                        TapHandler {
                            onTapped: root.join(modelData.ssid, modelData.security)
                        }
                    }
                }

                Text {
                    visible: root.networks.length === 0
                    text: !root.radioOn ? "radio off" : root.scanning ? "scanning…" : "no networks found"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }

                // passphrase entry for a secured network we have never joined
                Rectangle {
                    visible: root.pendingSsid !== ""
                    width: col.width
                    height: 26
                    radius: 6
                    color: Theme.surface
                    onVisibleChanged: if (visible)
                        pwInput.forceActiveFocus()

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        visible: pwInput.text === ""
                        text: "passphrase for " + root.pendingSsid + " — Enter to join"
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 2
                    }
                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                        onAccepted: {
                            root.doConnect(root.pendingSsid, text);
                            text = "";
                        }
                        Keys.onEscapePressed: {
                            text = "";
                            root.pendingSsid = "";
                        }
                    }
                }

                Text {
                    visible: root.status !== ""
                    width: col.width
                    wrapMode: Text.WordWrap
                    text: root.status
                    color: Theme.warn
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Theme.surface
                }

                // footer: rescan, and the escape hatch for static IPs / 802.1X
                Row {
                    spacing: 12
                    Text {
                        text: root.scanning ? "scanning…" : "rescan"
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 2
                        TapHandler {
                            onTapped: root.scan(true)
                        }
                    }
                    Text {
                        text: "advanced…"
                        color: Theme.subtext
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 2
                        TapHandler {
                            onTapped: {
                                popup.visible = false;
                                Quickshell.execDetached(["nm-connection-editor"]);
                            }
                        }
                    }
                }
            }
        }
    }

    // Active connection name + type.
    Process {
        id: conProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                if (line === "") {
                    root.conName = "";
                    root.conType = "";
                    return;
                }
                const parts = root.parseFields(line);
                root.conName = parts[0] ?? "";
                root.conType = (parts[1] ?? "").includes("ethernet") ? "ethernet" : "wifi";
            }
        }
    }

    // Wifi signal strength of the active AP.
    Process {
        id: sigProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi | grep '^yes' | head -n1 | cut -d: -f2"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                root.signal = s === "" ? -1 : parseInt(s);
            }
        }
    }

    // Radio state. `nmcli radio wifi` reports NM's view ANDed with rfkill, so
    // an externally-set soft block shows up here as "disabled" too.
    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.radioOn = this.text.trim() === "enabled"
        }
    }

    // Saved profiles → which SSIDs can join without a passphrase prompt.
    Process {
        id: savedProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | sed 's/:802-11-wireless$//'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line !== "")
                        out.push(root.parseFields(line)[0]);
                }
                root.savedSsids = out;
            }
        }
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                // Strongest BSS wins per SSID; hidden APs report an empty SSID
                // and are unjoinable by name, so drop them.
                const best = {};
                for (const line of this.text.trim().split("\n")) {
                    if (line === "")
                        continue;
                    const f = root.parseFields(line);
                    const ssid = f[3] ?? "";
                    if (ssid === "")
                        continue;
                    const entry = {
                        ssid: ssid,
                        signal: parseInt(f[1] ?? "0") || 0,
                        security: (f[2] ?? "").trim(),
                        inUse: (f[0] ?? "") === "*"
                    };
                    if (!best[ssid] || entry.signal > best[ssid].signal)
                        best[ssid] = entry;
                }
                const list = Object.values(best).sort((a, b) => b.signal - a.signal);
                root.networks = list.slice(0, 8);
                root.scanning = false;
            }
        }
    }

    Process {
        id: connProc
        stderr: StdioCollector {
            id: connErr
        }
        onExited: exitCode => {
            root.pendingSsid = "";
            if (exitCode === 0) {
                root.status = "";
                popup.visible = false;
                root.refreshAll();
            } else {
                const lines = connErr.text.trim().split("\n");
                root.status = lines[lines.length - 1] || "connection failed";
            }
        }
    }

    // Radio toggles take a beat to settle; re-read then rescan.
    Timer {
        id: radioTick
        interval: 800
        onTriggered: {
            root.refreshAll();
            root.scan(true);
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            conProc.running = true;
            sigProc.running = true;
            radioProc.running = true;
            // Only sweep while the user is actually looking at the list.
            if (popup.visible)
                root.scan(false);
        }
    }
}
