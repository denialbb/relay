// ConversationView.qml — Full conversation view with header, scroller, and composer.
// Spec: docs/relay_beeper_triage_spec.md §7.5, §9, §15.
import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property var chat: null
    property var messages: []
    property bool busy: false

    signal requestBack()
    signal requestMarkRead()
    signal requestOpenInBeeper()
    signal submitReply(string text)

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    readonly property string chatTitle: root.chat ? (root.chat.title || "Chat") : "Chat"
    readonly property bool isReadOnly: root.chat ? Boolean(root.chat.isReadOnly) : false
    readonly property bool canMarkRead: root.chat ? (typeof root.chat.unreadCount === "number" && root.chat.unreadCount > 0) : false
    readonly property color backTextColor: backMouseArea.containsMouse ? root.theme.accent : root.theme.textPrimary
    readonly property color markReadTextColor: markReadMouseArea.containsMouse ? root.theme.accent : root.theme.textSecondary
    readonly property color beeperTextColor: beeperMouseArea.containsMouse ? root.theme.accent : root.theme.textSecondary

    implicitWidth: 380
    implicitHeight: 500

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Top Header
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            implicitHeight: root.metrics.barHeight
            color: root.theme.surface
            border.color: root.theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.metrics.spacingMD
                anchors.rightMargin: root.metrics.spacingMD
                spacing: root.metrics.spacingSM

                // Back button
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: root.metrics.radiusSM
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: 16
                        font.bold: true
                        color: root.backTextColor
                    }

                    MouseArea {
                        id: backMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestBack()
                    }
                }

                // Chat title
                Text {
                    Layout.fillWidth: true
                    text: root.chatTitle
                    color: root.theme.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // Mark read action
                Rectangle {
                    visible: root.canMarkRead
                    implicitWidth: markReadText.implicitWidth + (root.metrics.spacingSM * 2)
                    implicitHeight: 28
                    radius: root.metrics.radiusSM
                    color: "transparent"

                    Text {
                        id: markReadText
                        anchors.centerIn: parent
                        text: "Mark read"
                        font.pixelSize: 12
                        color: root.markReadTextColor
                    }

                    MouseArea {
                        id: markReadMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestMarkRead()
                    }
                }

                // Open in Beeper action
                Rectangle {
                    implicitWidth: beeperText.implicitWidth + (root.metrics.spacingSM * 2)
                    implicitHeight: 28
                    radius: root.metrics.radiusSM
                    color: "transparent"

                    Text {
                        id: beeperText
                        anchors.centerIn: parent
                        text: "Beeper ↗"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.beeperTextColor
                    }

                    MouseArea {
                        id: beeperMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestOpenInBeeper()
                    }
                }
            }
        }

        // 2. Message Scroller
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: messageListView
                anchors.fill: parent
                anchors.margins: root.metrics.spacingSM
                clip: true
                spacing: root.metrics.spacingSM
                model: root.messages

                delegate: MessageRow {
                    width: messageListView.width
                    message: modelData
                    onOpenInBeeper: root.requestOpenInBeeper()
                }

                onCountChanged: {
                    messageListView.positionViewAtEnd()
                }
            }
        }

        // 3. Bottom Composer
        Composer {
            id: replyComposer
            Layout.fillWidth: true
            enabled: !root.isReadOnly
            busy: root.busy
            onSubmit: function(text) {
                root.submitReply(text)
            }
        }
    }
}
