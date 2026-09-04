// Stub: conversation view. input: chat, messages. output: requestMarkRead(), requestOpenInBeeper().
import QtQuick

Item {
    property var chat
    property var messages: []
    signal requestMarkRead()
    signal requestOpenInBeeper()
}
