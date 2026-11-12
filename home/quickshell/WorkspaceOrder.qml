pragma Singleton
// WorkspaceOrder.qml — position-based workspace numbers (the wish, 2026-11-12).
//
// Hyprland's workspace id is a permanent identity: "2" stays 2 wherever it
// lives, so with a laptop left of an external screen you could end up looking
// at "2" and "4". The bar never shows that id. It numbers workspaces by
// where they sit instead: screens left to right (then top to bottom), and
// within a screen by id, so a new workspace lands at the end of its screen.
// Add one on the laptop and the external's numbers shift up by one, which is
// the point: the number is a position, and the pill's icon + purpose label
// (WorkspaceNames.qml) say what lives there.
//
// Named workspaces (a resumed context, `resume <name>`) sort after the
// numbered ones on their screen. Special workspaces are left out.
//
// MIRROR: home/hyprland.nix `claudeos_ordered_workspaces` sorts the same way
// for Super+<n>, so pill N and Super+N always agree. Change one, change both.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // Within a screen: numbered ids ascending, then named (negative ids).
    function _key(id) {
        return id > 0 ? id : 1000000 - id;
    }
    function _compare(a, b) {
        const ma = a.monitor, mb = b.monitor;
        if (!ma || !mb)
            return (ma ? 0 : 1) - (mb ? 0 : 1);
        if (ma.x !== mb.x)
            return ma.x - mb.x;
        if (ma.y !== mb.y)
            return ma.y - mb.y;
        return root._key(a.id) - root._key(b.id);
    }

    // HyprlandWorkspace objects in screen order.
    readonly property var ordered: (Hyprland.workspaces?.values ?? []).filter(w => !String(w.name).startsWith("special")).sort(root._compare)

    // id → 1-based position. Reassigned as a whole, so bindings notify.
    readonly property var numbers: {
        const m = {};
        root.ordered.forEach((w, i) => m[w.id] = i + 1);
        return m;
    }
    function numberOf(id) {
        return root.numbers[id] ?? "";
    }
    // The workspace `step` places away from `id` in screen order (wheel
    // cycling); null past either end.
    function neighbour(id, step) {
        const i = root.ordered.findIndex(w => w.id === id);
        return i < 0 ? null : (root.ordered[i + step] ?? null);
    }
}
