// Composer.qml — Reply composer with Ctrl+Enter sending and busy state.
// Spec: docs/relay_beeper_triage_spec.md §7.5, §9.2, §15.
import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property bool enabled: true
    property bool busy: false
    signal submit(string text)

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    readonly property bool canSubmit: root.enabled && !root.busy && textEdit.text.trim().length > 0
    readonly property color borderColor: textEdit.activeFocus ? root.theme.accent : root.theme.border
    readonly property color inputTextColor: root.enabled ? root.theme.textPrimary : root.theme.textDisabled
    readonly property bool inputReadOnly: !root.enabled || root.busy
    readonly property color hintTextColor: root.canSubmit ? root.theme.textSecondary : root.theme.textDisabled
    readonly property color buttonBgColor: root.canSubmit ? (sendMouseArea.containsMouse ? root.theme.accent : root.theme.surface) : root.theme.surface
    readonly property color buttonBorderColor: root.canSubmit ? root.theme.accent : root.theme.border
    readonly property color buttonTextColor: root.canSubmit ? (sendMouseArea.containsMouse ? root.theme.background : root.theme.textPrimary) : root.theme.textDisabled
    readonly property int buttonCursor: root.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor

    implicitWidth: 360
    implicitHeight: Math.max(root.metrics.barHeight, container.implicitHeight)
    width: parent ? parent.width : implicitWidth

    Rectangle {
        id: container
        anchors.fill: parent
        implicitHeight: contentRow.implicitHeight + (root.metrics.spacingSM * 2)
        color: root.theme.surfaceRaised
        border.color: root.borderColor
        border.width: 1
        radius: root.metrics.radiusMD

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: root.metrics.spacingSM
            spacing: root.metrics.spacingSM

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.max(24, textEdit.implicitHeight)

                Text {
                    id: placeholder
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.topMargin: 2
                    visible: textEdit.text.length === 0
                    text: "Reply…"
                    color: root.theme.textSecondary
                    font.pixelSize: 13
                }

                TextEdit {
                    id: textEdit
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.topMargin: 2
                    color: root.inputTextColor
                    readOnly: root.inputReadOnly
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: 13
                    selectByMouse: true

                    Keys.onPressed: function(event) {
                        root.handleKeyPress(event)
                    }
                }
            }

            // Right side: Busy indicator or Send hint / button
            Item {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: root.busy ? 18 : actionRow.implicitWidth
                implicitHeight: 24

                // Busy spinner
                Item {
                    id: busyIndicator
                    visible: root.busy
                    width: 18
                    height: 18
                    anchors.centerIn: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: root.theme.accent
                        border.width: 2
                        opacity: 0.8

                        RotationAnimation on rotation {
                            running: root.busy
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }
                }

                // Send action & shortcut hint
                RowLayout {
                    id: actionRow
                    visible: !root.busy
                    spacing: root.metrics.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Ctrl+Enter"
                        color: root.hintTextColor
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: root.metrics.radiusSM
                        color: root.buttonBgColor
                        border.color: root.buttonBorderColor
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            font.bold: true
                            font.pixelSize: 13
                            color: root.buttonTextColor
                        }

                        MouseArea {
                            id: sendMouseArea
                            anchors.fill: parent
                            enabled: root.canSubmit
                            hoverEnabled: true
                            cursorShape: root.buttonCursor
                            onClicked: root.submitCurrentText()
                        }
                    }
                }
            }
        }
    }

    function focusInput() {
        textEdit.forceActiveFocus()
    }

    function isSubmitCombo(event) {
        var isEnter = (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        return isEnter && ((event.modifiers & Qt.ControlModifier) !== 0)
    }

    function handleKeyPress(event) {
        if (!event) return
        if (event.key === Qt.Key_Escape) {
            textEdit.focus = false
            return
        }
        if (root.isSubmitCombo(event)) {
            root.submitCurrentText()
            event.accepted = true
        }
    }

    function submitCurrentText() {
        if (!root.enabled || root.busy) return
        var t = textEdit.text.trim()
        if (t.length === 0) return
        textEdit.text = ""
        root.submit(t)
    }
}
