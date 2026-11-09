pragma Singleton
// BarRegions.qml — where the bar's islands sit on each monitor, for the region
// tool (RegionShot.qml).
//
// The selector's hover/click/snap targets come from Hyprland.toplevels, which
// lists client windows only. The bar is a layer-shell surface, so it is in the
// frozen frame but invisible to the picker: no hover outline, a click on the
// island takes nothing, and box edges never snap to it. Each Bar (one per
// monitor) registers its three pills here; RegionShot snapshots their rects at
// freeze time so the targets match the frame even if the island resizes after.
//
// Rects are monitor-relative: the bar window is anchored top/left/right with no
// margins, so a pill's position in the bar window *is* its position on the
// monitor.
import Quickshell

Singleton {
    id: root

    // monitor name → [{label, item}]. Reassigned (never mutated) so readers notice.
    property var byMonitor: ({})

    function register(monitor, pieces) {
        const next = Object.assign({}, root.byMonitor);
        next[monitor] = pieces;
        root.byMonitor = next;
    }
    function unregister(monitor) {
        const next = Object.assign({}, root.byMonitor);
        delete next[monitor];
        root.byMonitor = next;
    }

    // [{label, r}] for MONITOR right now; hidden or empty pieces are skipped.
    function rectsFor(monitor) {
        return (root.byMonitor[monitor] ?? []).filter(p => p.item && p.item.visible && p.item.width > 0 && p.item.height > 0).map(p => ({
                    label: p.label,
                    r: Qt.rect(Math.round(p.item.x), Math.round(p.item.y), Math.round(p.item.width), Math.round(p.item.height))
                }));
    }
}
