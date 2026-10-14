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
    property bool atBottom: true

    signal requestOpenInBeeper()
    signal submitReply(string text)

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    readonly property bool isReadOnly: root.chat ? Boolean(root.chat.isReadOnly) : false
    readonly property bool isComposerFocused: replyComposer.isInputFocused

    implicitWidth: 380
    implicitHeight: 500

    onChatChanged: {
        root.atBottom = true
        Qt.callLater(root.scrollToBottom)
    }

    onMessagesChanged: {
        if (root.atBottom) Qt.callLater(root.scrollToBottom)
    }

    onVisibleChanged: {
        if (root.visible) {
            root.atBottom = true
            Qt.callLater(root.scrollToBottom)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Message Scroller
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
                    if (root.atBottom) Qt.callLater(root.scrollToBottom)
                }

                onContentHeightChanged: {
                    if (root.atBottom) Qt.callLater(root.scrollToBottom)
                }

                onHeightChanged: {
                    if (root.atBottom) Qt.callLater(root.scrollToBottom)
                    else root.clampScroll()
                }

                onMovementStarted: {
                    if (messageListView.dragging || messageListView.flicking) {
                        root.atBottom = false
                    }
                }

                onContentYChanged: {
                    if (!scrollAnim.running) {
                        var maxY = root.maxContentY()
                        if (messageListView.contentY >= maxY - 2) {
                            root.atBottom = true
                        }
                    }
                }

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0) {
                            root.atBottom = false
                        }
                    }
                }
            }
        }

        // Bottom Composer
        Composer {
            id: replyComposer
            Layout.fillWidth: true
            Layout.leftMargin: root.metrics.spacingMD
            Layout.rightMargin: root.metrics.spacingMD
            Layout.bottomMargin: root.metrics.spacingSM
            enabled: !root.isReadOnly
            busy: root.busy
            onSubmit: function(text) {
                root.atBottom = true
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

    function maxContentY() {
        var minY = messageListView.originY
        return Math.max(minY, minY + messageListView.contentHeight - messageListView.height)
    }

    function clampScroll() {
        var minY = messageListView.originY
        var maxY = root.maxContentY()
        if (messageListView.contentY > maxY) messageListView.contentY = maxY
        if (messageListView.contentY < minY) messageListView.contentY = minY
    }

    function scrollBy(delta) {
        var minY = messageListView.originY
        var maxY = root.maxContentY()
        var curY = scrollAnim.running ? scrollAnim.to : messageListView.contentY
        var nextY = Math.max(minY, Math.min(curY + delta, maxY))
        if (nextY >= maxY - 2) root.atBottom = true
        scrollAnim.stop()
        scrollAnim.from = messageListView.contentY
        scrollAnim.to = nextY
        scrollAnim.start()
    }

    function scrollDown() {
        root.scrollBy(75)
    }

    function scrollUp() {
        root.atBottom = false
        root.scrollBy(-75)
    }

    function scrollToBottom() {
        scrollAnim.stop()
        if (messageListView.count > 0) {
            messageListView.positionViewAtEnd()
            messageListView.contentY = root.maxContentY()
        }
    }

    function focusComposer() {
        replyComposer.focusInput()
    }

    function blurComposer() {
        replyComposer.blur()
    }
}
