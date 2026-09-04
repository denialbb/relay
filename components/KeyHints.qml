import QtQuick

// KeyHints — bottom shortcut hints bar displaying active context keybindings.
Row {
    id: root

    property color textColor: "#ffffff"
    property color dimColor: "#888888"
    property color badgeColor: "#2a2a2a"
    property int fontPixelSize: 11
    property int badgeRadius: 4
    property string fontFamily: ""

    // [{ key: "j / k", label: "move" }, ...]
    property var hints: []

    spacing: 12

    Repeater {
        model: root.hints

        delegate: Row {
            id: pair
            required property var modelData
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: cap.implicitWidth + 8
                height: cap.implicitHeight + 4
                radius: root.badgeRadius
                color: root.badgeColor

                Text {
                    id: cap
                    anchors.centerIn: parent
                    text: pair.modelData && pair.modelData.key ? pair.modelData.key : ""
                    color: root.textColor
                    font.pixelSize: root.fontPixelSize
                    font.family: root.fontFamily
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pair.modelData && pair.modelData.label ? pair.modelData.label : ""
                color: root.dimColor
                font.pixelSize: root.fontPixelSize
                font.family: root.fontFamily
            }
        }
    }
}
