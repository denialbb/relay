// UnsupportedMessage.qml — Fallback box for media or non-text messages.
// Spec: docs/relay_beeper_triage_spec.md §7.5, §11, §15.
import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property var message: null
    signal openInBeeper()

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    implicitWidth: 320
    implicitHeight: container.implicitHeight
    width: parent ? parent.width : implicitWidth

    Rectangle {
        id: container
        anchors.fill: parent
        implicitHeight: contentRow.implicitHeight + (root.metrics.spacingMD * 2)
        color: root.theme.surfaceRaised
        border.color: mouseArea.containsMouse ? root.theme.accent : root.theme.border
        border.width: 1
        radius: root.metrics.radiusMD

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.metrics.spacingSM

            Text {
                text: "Unsupported in Relay · Open in Beeper ↗"
                color: mouseArea.containsMouse ? root.theme.accent : root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openInBeeper()
        }
    }
}
