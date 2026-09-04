// ErrorState.qml — explicit error state displaying human error reason and Retry button emitting retry().
import QtQuick
import "../theme"
import "ErrorStateHelper.js" as Helper

Item {
    id: root

    property string error: ""
    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    signal retry()

    implicitWidth: 300
    implicitHeight: 220

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.metrics.spacingXL * 2, 340)
        spacing: root.metrics.spacingMD

        Rectangle {
            width: 44
            height: 44
            radius: 22
            color: root.theme.surfaceRaised
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "!"
                font.bold: true
                font.pixelSize: 22
                color: root.theme.error
            }
        }

        Text {
            width: parent.width
            text: "Connection Error"
            color: root.theme.textPrimary
            font.bold: true
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
        }

        Text {
            width: parent.width
            text: Helper.humanErrorMessage(root.error)
            color: root.theme.textSecondary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }

        Item {
            width: parent.width
            height: root.metrics.spacingXS
        }

        Rectangle {
            id: retryBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 100
            height: 32
            radius: root.metrics.radiusSM
            color: buttonMouseArea.containsMouse ? root.theme.surfaceRaised : root.theme.surface
            border.color: buttonMouseArea.containsMouse ? root.theme.accent : root.theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Retry"
                color: buttonMouseArea.containsMouse ? root.theme.accent : root.theme.textPrimary
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: buttonMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.retry()
            }
        }
    }
}
