import QtQuick
import "../theme"

Item {
    id: root

    property bool showMutedChats: false
    property bool showLowPriorityChats: false
    property int selectedIndex: 0
    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    signal settingSelected(int index)
    signal settingToggled(int index)

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.metrics.spacingXL * 2, 340)
        spacing: root.metrics.spacingMD

        Text {
            text: "Inbox filters"
            color: root.theme.textPrimary
            font.family: root.theme.fontFamily
            font.bold: true
            font.pixelSize: 15
            textFormat: Text.PlainText
        }

        Repeater {
            model: ["Show muted chats", "Show low-priority chats"]

            delegate: Rectangle {
                id: option
                required property int index
                required property string modelData

                width: parent.width
                height: 44
                radius: root.metrics.radiusSM
                color: root.selectedIndex === index ? root.theme.surfaceRaised : root.theme.surface
                border.color: root.selectedIndex === index ? root.theme.accent : root.theme.border
                border.width: 1

                property bool checked: index === 0 ? root.showMutedChats : root.showLowPriorityChats

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.metrics.spacingMD
                    anchors.rightMargin: root.metrics.spacingMD
                    spacing: root.metrics.spacingSM

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: option.checked ? root.theme.accent : "transparent"
                        border.color: option.checked ? root.theme.accent : root.theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: option.checked ? "✓" : ""
                            color: root.theme.background
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.settingSelected(option.index);
                        root.settingToggled(option.index);
                    }
                }
            }
        }
    }
}
