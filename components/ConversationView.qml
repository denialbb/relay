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

    NumberAnimation {
        id: scrollAnim
        target: messageListView
        property: "contentY"
        duration: 150
        easing.type: Easing.OutCubic
    }

    function scrollBy(delta) {
        var minY = messageListView.originY
        var maxY = Math.max(minY, minY + messageListView.contentHeight - messageListView.height)
        var curY = scrollAnim.running ? scrollAnim.to : messageListView.contentY
        var nextY = Math.max(minY, Math.min(curY + delta, maxY))
        scrollAnim.stop()
        scrollAnim.from = messageListView.contentY
        scrollAnim.to = nextY
        scrollAnim.start()
    }

    function scrollDown() {
        root.scrollBy(100)
    }

    function scrollUp() {
        root.scrollBy(-100)
    }

    function focusComposer() {
        replyComposer.focusInput()
    }
}
