// ActiveWindow.qml — the focused window's title (live-updating; blank when
// nothing is focused).
import QtQuick
import Quickshell.Hyprland

Text {
    color: Theme.subtext
    elide: Text.ElideRight
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontSize
    text: Hyprland.activeToplevel?.title ?? ""
    visible: text !== ""
}
