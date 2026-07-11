// Calendar.qml — a month grid (Qt Quick Controls MonthGrid), with prev/next
// month arrows. Today is highlighted in terracotta.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property date shown: new Date()
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
                onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() - 1, 1)
            }
        }
        Text {
            text: Icons.chevronRight
            color: Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: 12
            leftPadding: 10
            TapHandler {
                onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 1)
            }
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: grid.locale
        delegate: Text {
            text: shortName
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MonthGrid {
        id: grid
        Layout.fillWidth: true
        month: root.shown.getMonth()
        year: root.shown.getFullYear()
        locale: Qt.locale()
        delegate: Text {
            horizontalAlignment: Text.AlignHCenter
            text: model.day
            opacity: model.month === grid.month ? 1 : 0.3
            color: model.today ? Theme.accent : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: model.today
        }
    }
}
