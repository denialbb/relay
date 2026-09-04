// Stub: unread chat list. input: chats[], selectedIndex. output: chatActivated(index).
import QtQuick

Item {
    property var chats: []
    property int selectedIndex: -1
    signal chatActivated(int index)
}
