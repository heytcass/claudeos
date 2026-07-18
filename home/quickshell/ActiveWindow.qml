// ActiveWindow.qml — the focused window as app icon + title. The icon comes
// from the toplevel's appId resolved through the desktop-entry index; the pair
// slides in on focus change instead of hard-snapping. Blank when nothing is
// focused.
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    readonly property var win: ToplevelManager.activeToplevel
    readonly property string title: win?.title ?? ""
    readonly property string appId: win?.appId ?? ""
    // Existence-checked path ("" when the theme has no such icon).
    readonly property string iconSource: {
        if (appId === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(appId);
        return entry ? Quickshell.iconPath(entry.icon, true) : "";
    }

    visible: title !== ""
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // Focus-change transition: new window's identity slides in from the left.
    // Keyed on appId (not title) so browser-tab retitles don't re-trigger it.
    onAppIdChanged: slide.restart()
    SequentialAnimation {
        id: slide
        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                from: 0
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content
                property: "x"
                from: -7
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: content
        spacing: 7

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: Theme.iconSize + 3
            sourceSize.height: Theme.iconSize + 3
            width: Theme.iconSize + 3
            height: Theme.iconSize + 3
            asynchronous: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtext
            elide: Text.ElideRight
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
            text: root.title
            width: Math.min(implicitWidth, 400)
        }
    }
}
