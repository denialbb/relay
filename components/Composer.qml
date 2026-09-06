import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property bool enabled: true
    property bool busy: false
    property string placeholderText: "Reply…"
    property string prefixText: ""
    property int maxExpandedHeight: 100
    signal submit(string text)
    signal escapePressed()
    signal growHeightRequested()
    signal shrinkHeightRequested()

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}

    readonly property bool canSubmit: root.enabled && !root.busy && textEdit.text.trim().length > 0
    readonly property color borderColor: textEdit.activeFocus ? root.theme.accent : root.theme.border
    readonly property color inputTextColor: root.enabled ? root.theme.textPrimary : root.theme.textDisabled
    readonly property bool inputReadOnly: !root.enabled || root.busy
    readonly property color hintTextColor: root.canSubmit ? root.theme.textSecondary : root.theme.textDisabled
    readonly property color buttonTextColor: root.canSubmit ? (sendMouseArea.containsMouse ? root.theme.accent : root.theme.textPrimary) : root.theme.textDisabled
    readonly property int buttonCursor: root.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor

    implicitWidth: 360
    implicitHeight: Math.min(root.maxExpandedHeight, Math.max(28, container.implicitHeight))
    width: parent ? parent.width : implicitWidth

    Rectangle {
        id: container
        anchors.fill: parent
        implicitHeight: contentRow.implicitHeight + (root.metrics.spacingXS * 2)
        color: root.theme.surfaceRaised
        border.color: root.borderColor
        border.width: 1
        radius: root.metrics.radiusMD

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: root.metrics.spacingSM
            anchors.rightMargin: root.metrics.spacingSM
            anchors.topMargin: root.metrics.spacingXS
            anchors.bottomMargin: root.metrics.spacingXS
            spacing: root.metrics.spacingSM

            Text {
                id: prefixLabel
                visible: root.prefixText.length > 0
                text: root.prefixText
                color: root.theme.accent
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: 100
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.max(20, textEdit.implicitHeight)

                Text {
                    id: placeholder
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 2
                    visible: textEdit.text.length === 0
                    text: root.placeholderText
                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                TextEdit {
                    id: textEdit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 2
                    color: root.inputTextColor
                    readOnly: root.inputReadOnly
                    wrapMode: TextEdit.Wrap
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                    selectByMouse: true

                    Keys.onPressed: function(event) {
                        root.handleKeyPress(event)
                    }
                }
            }

            Item {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: root.busy ? 18 : actionRow.implicitWidth
                implicitHeight: 20

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

                RowLayout {
                    id: actionRow
                    visible: !root.busy
                    spacing: root.metrics.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Enter"
                        color: root.hintTextColor
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11
                    }

                    Item {
                        width: 20
                        height: 20

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            font.bold: true
                            font.family: root.theme.fontFamily
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

    readonly property bool isInputFocused: textEdit.activeFocus
    property alias text: textEdit.text

    function focusInput() {
        textEdit.forceActiveFocus()
    }

    function blur() {
        textEdit.focus = false
    }

    function isSubmitCombo(event) {
        var isEnter = (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        var isShift = (event.modifiers & Qt.ShiftModifier) !== 0
        return isEnter && !isShift
    }

    function handleResizeKeys(event) {
        var isCtrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (!isCtrl) return false
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            root.growHeightRequested()
            return true
        }
        if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            root.shrinkHeightRequested()
            return true
        }
        return false
    }

    function handleKeyPress(event) {
        if (!event) return
        if (event.key === Qt.Key_Escape) {
            root.blur()
            root.escapePressed()
            event.accepted = true
            return
        }
        if (root.handleResizeKeys(event)) {
            event.accepted = true
            return
        }
        if (root.isSubmitCombo(event)) {
            root.submitCurrentText()
            event.accepted = true
            return
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
