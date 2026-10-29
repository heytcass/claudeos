// WindowThumb.qml — one window as a live picture: a ScreencopyView of the
// toplevel (works even when its workspace is hidden), with the app icon as the
// whole face until the first frame lands and a small corner badge after.
// Shared by Overview (drag tiles), Pin (the corner mini-window) and
// WorkspacePeek (the bar-pill hover preview). Capture runs only while
// `active` — keep it bound to the owner's visibility.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Rectangle {
    id: root
    // A HyprlandToplevel.
    required property var toplevel
    property bool active: true
    property bool highlighted: false
    property real badgeSize: 20
    readonly property bool hasContent: view.hasContent
    readonly property var entry: DesktopEntries.heuristicLookup(toplevel?.lastIpcObject?.class ?? "")

    radius: Theme.radius / 2
    color: Theme.bgAlt
    border.width: highlighted ? 2 : 0
    border.color: Theme.accent
    clip: true

    ScreencopyView {
        id: view
        anchors.fill: parent
        anchors.margins: parent.border.width
        captureSource: root.active ? (root.toplevel?.wayland ?? null) : null
        live: root.active
    }

    // Plain x/y rather than toggled anchors: setting an anchor back to
    // `undefined` doesn't release it, so the badge stuck in the centre.
    IconImage {
        readonly property real big: Math.min(parent.width, parent.height) * 0.4
        implicitSize: view.hasContent ? Math.min(root.badgeSize, big) : big
        x: view.hasContent ? parent.width - width - 4 : (parent.width - width) / 2
        y: view.hasContent ? parent.height - height - 4 : (parent.height - height) / 2
        source: root.entry ? Quickshell.iconPath(root.entry.icon, true) : ""
        visible: source !== ""
    }
}
