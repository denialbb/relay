// Stub: reply composer. input: enabled, busy. output: submit(text).
import QtQuick

Item {
    property bool enabled: false
    property bool busy: false
    signal submit(string text)
}
