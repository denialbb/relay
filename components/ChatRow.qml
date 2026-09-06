// ChatRow.qml — single triage chat row with unread dot, snippet, timestamp, avatar, and jitter-free hover/cursor states.
import QtQuick
import qs.Commons
import "../theme"
import "ChatRowHelper.js" as Helper

Rectangle {
    id: root

    property var chat: null
    property bool selected: false
    property bool hasCursor: false
    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    signal clicked()

    readonly property bool isUnread: Boolean(root.chat && root.chat.unreadCount > 0)
    readonly property bool hot: mouseArea.containsMouse || root.hasCursor
    readonly property string chatLastActivity: root.chat
        ? (root.chat.lastActivity || (root.chat.preview ? root.chat.preview.timestamp : ""))
        : ""
    readonly property string chatAvatarUrl: (root.chat && root.chat.avatarUrl) ? root.chat.avatarUrl : ""
    readonly property string chatTitleText: root.chat ? (root.chat.title || "Unknown") : ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(metrics.barHeight, contentRow.implicitHeight + metrics.spacingSM * 2)
    radius: metrics.radiusMD
    border.width: 1
    border.color: (root.hasCursor && !root.selected) ? root.theme.accent : "transparent"

    color: root.selected
        ? (typeof Style !== "undefined" && Style && Style.selectedFillFor
            ? Style.selectedFillFor(root.theme.textPrimary, root.theme.accent)
            : Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.18))
        : (root.hot
            ? (typeof Style !== "undefined" && Style && Style.hoverFillFor
                ? Style.hoverFillFor(root.theme.textPrimary, root.theme.accent)
                : Qt.rgba(root.theme.textPrimary.r, root.theme.textPrimary.g, root.theme.textPrimary.b, 0.08))
            : "transparent")

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.metrics.spacingSM
        anchors.rightMargin: root.metrics.spacingSM
        spacing: root.metrics.spacingSM

        Item {
            width: 8
            height: 8
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: root.theme.accent
                opacity: root.isUnread ? 1.0 : 0.0
            }
        }

        Rectangle {
            id: avatarBox
            width: 32
            height: 32
            radius: 16
            color: root.theme.surfaceRaised
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: avatarImg
                anchors.fill: parent
                source: (root.chat && root.chat.avatarUrl) ? root.chat.avatarUrl : ""
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: (source !== "") && (status !== Image.Error)
                opacity: status === Image.Ready ? 1.0 : 0.0
            }

            Text {
                anchors.centerIn: parent
                visible: !root.chat || !root.chat.avatarUrl || avatarImg.status === Image.Error
                text: Helper.getInitials(root.chat ? root.chat.title : "")
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.bold: true
                font.pixelSize: 12
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, contentRow.width - 8 - 32 - root.metrics.spacingSM * 2)
            spacing: 2

            Item {
                width: parent.width
                implicitHeight: Math.max(titleText.implicitHeight, metaColumn.implicitHeight)

                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.right: metaColumn.left
                    anchors.rightMargin: root.metrics.spacingSM
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.chat ? (root.chat.title || "Unknown") : ""
                    font.bold: true
                    font.family: root.theme.fontFamily
                    color: root.theme.textPrimary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Column {
                    id: metaColumn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        id: timeText
                        anchors.right: parent.right
                        text: Helper.formatTimestamp(root.chatLastActivity)
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        textFormat: Text.PlainText
                    }

                    Text {
                        id: pinText
                        anchors.right: parent.right
                        visible: Boolean(root.chat && root.chat.isPinned)
                        text: "\uf08d"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                    }
                }
            }

            Text {
                id: snippetText
                width: parent.width
                text: Helper.formatSnippet(root.chat)
                color: root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
