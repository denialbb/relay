// EmptyState.qml — empty inbox slate when all unread messages are caught up.
import QtQuick
import "../theme"

Item {
    id: root

    property string title: "Inbox zero"
    property string message: "All caught up"
    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    implicitWidth: 280
    implicitHeight: 200

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.metrics.spacingXL * 2, 320)
        spacing: root.metrics.spacingSM

        Rectangle {
            width: 44
            height: 44
            radius: 22
            color: root.theme.surfaceRaised
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 20
                color: root.theme.success
            }
        }

        Text {
            width: parent.width
            text: root.title
            color: root.theme.textPrimary
            font.bold: true
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
        }

        Text {
            width: parent.width
            text: root.message
            color: root.theme.textSecondary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }
}
