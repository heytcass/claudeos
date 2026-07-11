// Calendar.qml — a month grid built by hand. Deliberately NO QtQuick.Controls
// (MonthGrid): the nixpkgs quickshell QML path ships only qtdeclarative, not
// qtquickcontrols2, so Controls types are unavailable. Prev/next arrows; today
// in terracotta; adjacent-month days dimmed.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property date shown: new Date()
    readonly property int y: shown.getFullYear()
    readonly property int m: shown.getMonth()
    // weekday index (0=Sun) of the 1st of the shown month
    readonly property int firstWeekday: new Date(y, m, 1).getDay()
    readonly property date today: new Date()

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontSans
            font.bold: true
            font.pixelSize: Theme.fontSize
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: Icons.chevronLeft
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 12
            TapHandler {
                onTapped: root.shown = new Date(root.y, root.m - 1, 1)
            }
        }
        Text {
            text: Icons.chevronRight
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 12
            leftPadding: 10
            TapHandler {
                onTapped: root.shown = new Date(root.y, root.m + 1, 1)
            }
        }
    }

    // weekday header
    Grid {
        Layout.fillWidth: true
        columns: 7
        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            delegate: Text {
                required property var modelData
                width: 36
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: 11
            }
        }
    }

    // 6 weeks x 7 days; JS Date normalises out-of-range days for the leading /
    // trailing cells (adjacent months).
    Grid {
        Layout.fillWidth: true
        columns: 7
        Repeater {
            model: 42
            delegate: Item {
                required property int index
                readonly property date cellDate: new Date(root.y, root.m, 1 - root.firstWeekday + index)
                width: 36
                height: 26

                Text {
                    anchors.centerIn: parent
                    text: parent.cellDate.getDate()
                    opacity: parent.cellDate.getMonth() === root.m ? 1 : 0.3
                    color: root.sameDay(parent.cellDate, root.today) ? Theme.accent : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.bold: root.sameDay(parent.cellDate, root.today)
                }
            }
        }
    }
}
