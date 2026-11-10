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
    readonly property string brightness: String.fromCharCode(0xf185)

    readonly property string play: String.fromCharCode(0xf04b)
    readonly property string pause: String.fromCharCode(0xf04c)
    readonly property string next: String.fromCharCode(0xf051)
    readonly property string prev: String.fromCharCode(0xf048)
    readonly property string music: String.fromCharCode(0xf001)

    readonly property string wifi: String.fromCharCode(0xf1eb)
    readonly property string ethernet: String.fromCharCode(0xf0e8)
    readonly property string lock: String.fromCharCode(0xf023)
    readonly property string refresh: String.fromCharCode(0xf021)

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
    readonly property string bluetooth: String.fromCharCode(0xf293)
    readonly property string power: String.fromCharCode(0xf011)

    readonly property string shelf: String.fromCharCode(0xf187)
    readonly property string file: String.fromCharCode(0xf15b)
    readonly property string link: String.fromCharCode(0xf0c1)
    readonly property string quote: String.fromCharCode(0xf10d)
    readonly property string close: String.fromCharCode(0xf00d)
    readonly property string check: String.fromCharCode(0xf00c)

    // summon action glyphs — named by lib/keybindings.nix `icon`
    readonly property string camera: String.fromCharCode(0xf030)
    readonly property string crosshairs: String.fromCharCode(0xf05b)
    readonly property string question: String.fromCharCode(0xf059)
    readonly property string font: String.fromCharCode(0xf031)
    readonly property string paste: String.fromCharCode(0xf0ea)
    readonly property string magic: String.fromCharCode(0xf0d0)
    readonly property string image: String.fromCharCode(0xf03e)
    readonly property string terminal: String.fromCharCode(0xf120)
    readonly property string comment: String.fromCharCode(0xf075)
    readonly property string eye: String.fromCharCode(0xf06e)
    readonly property string search: String.fromCharCode(0xf002)

    // metadata-tag glyphs (Notifications.clean)
    readonly property string ci: String.fromCharCode(0xf126)       // code-fork
    readonly property string sessions: String.fromCharCode(0xf0c0) // users
    readonly property string tasks: String.fromCharCode(0xf0ae)    // tasks
}
