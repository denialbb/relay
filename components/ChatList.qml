// ChatList.qml — unread chat list with Flickable, Column, and Repeater to prevent scroll conflicts.
import QtQuick
import "../theme"

Flickable {
    id: root

    property var chats: []
    property int selectedIndex: -1
    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    signal chatActivated(int index)

    width: parent ? parent.width : 0
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height

    Column {
        id: column
        width: root.width
        spacing: root.metrics.spacingXS

        Repeater {
            id: repeater
            model: root.chats

            ChatRow {
                required property var modelData
                required property int index

                width: column.width
                chat: modelData
                selected: root.selectedIndex === index
                hasCursor: root.selectedIndex === index
                theme: root.theme
                metrics: root.metrics

                onClicked: root.chatActivated(index)
            }
        }
    }

    onSelectedIndexChanged: root.ensureIndexVisible(root.selectedIndex)
    onHeightChanged: {
        root.clampContentY()
        root.ensureIndexVisible(root.selectedIndex)
    }

    function clampContentY() {
        var maxY = Math.max(0, root.contentHeight - root.height)
        if (root.contentY > maxY) root.contentY = maxY
        if (root.contentY < 0) root.contentY = 0
    }

    function ensureIndexVisible(idx) {
        if (idx < 0 || idx >= repeater.count) return
        var item = repeater.itemAt(idx)
        if (!item) return
        var top = item.y
        var bottom = item.y + item.height
        if (top < root.contentY) {
            root.contentY = top
        } else if (bottom > root.contentY + root.height) {
            root.contentY = bottom - root.height
        }
    }
}
