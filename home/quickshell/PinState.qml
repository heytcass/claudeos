pragma Singleton
// PinState.qml — which window is pinned as the corner mini-window (Pin.qml).
// A singleton so anything can pin: SUPER+O (the focused window) and a
// right-click on a window in the Overview. One pin at a time — pinning another
// window replaces it, pinning the same one again unpins.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    // Client address with its 0x prefix, or "" for no pin.
    property string address: ""
    // Which screen corner: 0 bottom-right, 1 bottom-left, 2 top-left, 3 top-right.
    property int corner: 0

    readonly property var toplevel: address === "" ? null : (Hyprland.toplevels?.values ?? []).find(t => norm(t.address) === address) ?? null

    function norm(a) {
        a = a ?? "";
        return a === "" || a.startsWith("0x") ? a : "0x" + a;
    }
    function toggle(t) {
        const a = norm(t?.address);
        address = (a === "" || a === address) ? "" : a;
    }

    // The window closed: drop the pin rather than keep an empty frame.
    onToplevelChanged: if (address !== "" && !toplevel)
        address = ""
}
