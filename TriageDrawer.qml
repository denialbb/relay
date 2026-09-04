// Stub: panel entry. Layout/focus/keyboard/composition only. No HTTP, no Beeper shapes.
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool open: false
    property int selectedIndex: -1
    signal requestClose()
    signal requestOpenInBeeper(string chatId)
}
