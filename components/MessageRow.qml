// MessageRow.qml — Single message row with sender, timestamp, state, and bubble alignment.
// Spec: docs/relay_beeper_triage_spec.md §7.5, §11, §12, §15.
import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property var message: null
    signal openInBeeper()

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    readonly property bool isMine: root.message ? Boolean(
        root.message.isMine ||
        root.message.is_sender ||
        root.message.is_self ||
        root.message.senderId === "me" ||
        root.message.senderName === "You" ||
        root.message.senderName === "Me"
    ) : false
    readonly property string sendState: root.message ? (root.message.sendState || "remote") : "remote"
    readonly property bool isUnsupported: root.message ? (root.message.kind === "unsupported") : false
    readonly property bool isPending: root.sendState === "pending"
    readonly property bool isFailedRetriable: root.sendState === "failed-retriable"
    readonly property bool isFailedPermanent: root.sendState === "failed-permanent"

    readonly property color statusColor: root.isFailedPermanent ? root.theme.error : (root.isFailedRetriable ? root.theme.warning : root.theme.textSecondary)
    readonly property string statusText: root.isFailedPermanent ? "Failed to send" : (root.isFailedRetriable ? "Failed · Retrying…" : "Sending…")

    implicitWidth: 360
    implicitHeight: bubbleContainer.implicitHeight + root.metrics.spacingSM
    width: parent ? parent.width : implicitWidth

    Item {
        id: bubbleContainer
        anchors.top: root.top
        anchors.topMargin: root.metrics.spacingXS
        anchors.left: root.isMine ? undefined : root.left
        anchors.right: root.isMine ? root.right : undefined
        anchors.leftMargin: root.metrics.spacingMD
        anchors.rightMargin: root.metrics.spacingMD
        width: Math.min(contentColumn.implicitWidth + (root.metrics.spacingMD * 2), root.width * 0.82)
        implicitHeight: bubbleRect.implicitHeight

        Rectangle {
            id: bubbleRect
            anchors.fill: parent
            implicitHeight: contentColumn.implicitHeight + (root.metrics.spacingSM * 2)
            color: root.isMine ? root.theme.surfaceRaised : root.theme.surface
            border.color: root.isMine ? root.theme.accent : root.theme.border
            border.width: 1
            radius: root.metrics.radiusMD
            opacity: root.isPending ? 0.65 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: root.metrics.animationNormal }
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: root.metrics.spacingSM
                spacing: root.metrics.spacingXS

                // Header: sender name and timestamp
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.metrics.spacingSM

                    Text {
                        text: root.message ? (root.message.senderName || (root.isMine ? "You" : "")) : ""
                        color: root.isMine ? root.theme.accent : root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.formatTime(root.message ? root.message.timestamp : null)
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                // Text message body
                Text {
                    visible: !root.isUnsupported
                    text: root.message ? (root.message.text || "") : ""
                    color: root.theme.textPrimary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 13
                    font.italic: root.isPending
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Unsupported message fallback
                UnsupportedMessage {
                    visible: root.isUnsupported
                    Layout.fillWidth: true
                    message: root.message
                    onOpenInBeeper: root.openInBeeper()
                }

                // Send state indicators
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.sendState !== "remote"
                    spacing: root.metrics.spacingXS

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.statusColor
                    }

                    Text {
                        text: root.statusText
                        color: root.statusColor
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                        font.italic: root.isPending
                    }
                }
            }
        }
    }

    function formatTime(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        if (isNaN(d.getTime())) return ""
        return Qt.formatTime(d, "hh:mm")
    }
}
