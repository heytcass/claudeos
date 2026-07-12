// Icons.qml — Nerd Font (JetBrains Mono Nerd Font) glyphs. Built via
// String.fromCharCode so the source stays plain ASCII (no fragile \u escapes /
// literal PUA glyphs). Codepoints are the classic Font Awesome PUA range,
// present in JetBrains Mono Nerd Font. Referenced as Icons.<name>.
pragma Singleton
import Quickshell

Singleton {
    readonly property string volumeHigh: String.fromCharCode(0xf028)
    readonly property string volumeLow: String.fromCharCode(0xf027)
    readonly property string volumeMute: String.fromCharCode(0xf026)

    readonly property string play: String.fromCharCode(0xf04b)
    readonly property string pause: String.fromCharCode(0xf04c)
    readonly property string next: String.fromCharCode(0xf051)
    readonly property string prev: String.fromCharCode(0xf048)
    readonly property string music: String.fromCharCode(0xf001)

    readonly property string wifi: String.fromCharCode(0xf1eb)
    readonly property string ethernet: String.fromCharCode(0xf0e8)

    readonly property string batFull: String.fromCharCode(0xf240)
    readonly property string batThreeQuarter: String.fromCharCode(0xf241)
    readonly property string batHalf: String.fromCharCode(0xf242)
    readonly property string batQuarter: String.fromCharCode(0xf243)
    readonly property string batEmpty: String.fromCharCode(0xf244)
    readonly property string charging: String.fromCharCode(0xf0e7)

    readonly property string chevronLeft: String.fromCharCode(0xf053)
    readonly property string chevronRight: String.fromCharCode(0xf054)
    readonly property string bell: String.fromCharCode(0xf0f3)

    readonly property string coffee: String.fromCharCode(0xf0f4)
}
