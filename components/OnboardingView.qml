import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property RelayTheme theme: RelayTheme {}
    property RelayMetrics metrics: RelayMetrics {}
    property bool showPassword: false

    signal saveToken(string token)

    implicitWidth: 360
    implicitHeight: 380

    onVisibleChanged: {
        if (visible) root.focusInput()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - root.metrics.spacingMD * 2, 340)
        spacing: root.metrics.spacingSM

        // Key / Shield icon
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 44
            height: 44
            radius: 22
            color: root.theme.surfaceRaised
            border.color: root.theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰌆"
                font.family: root.theme.fontFamily
                font.pixelSize: 22
                color: root.theme.accent
            }
        }

        // Title
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Connect Beeper Desktop"
            font.bold: true
            font.family: root.theme.fontFamily
            font.pixelSize: 15
            color: root.theme.textPrimary
            textFormat: Text.PlainText
        }

        // Explainer steps
        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.metrics.spacingXS

            Text {
                Layout.fillWidth: true
                text: "To triage messages, Relay needs your local API token:"
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                color: root.theme.textSecondary
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                text: "1. In Beeper Desktop: Settings → Developers"
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                color: root.theme.textPrimary
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                text: "2. Copy your API Access Token"
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                color: root.theme.textPrimary
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                text: "3. Paste it below and press Enter:"
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                color: root.theme.textPrimary
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }
        }

        // Token Input Container
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: root.metrics.radiusSM
            color: root.theme.surfaceRaised
            border.color: tokenInput.activeFocus ? root.theme.accent : root.theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.metrics.spacingSM
                anchors.rightMargin: root.metrics.spacingSM
                spacing: root.metrics.spacingXS

                TextInput {
                    id: tokenInput
                    Layout.fillWidth: true
                    color: root.theme.textPrimary
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: tokenInput.text.length === 0
                        text: "Paste token here…"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.submit();
                            event.accepted = true;
                        }
                    }
                }

                // Show/hide toggle
                MouseArea {
                    implicitWidth: 20
                    implicitHeight: 20
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showPassword = !root.showPassword

                    Text {
                        anchors.centerIn: parent
                        text: root.showPassword ? "󰈈" : "󰈉"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                        color: root.theme.textSecondary
                    }
                }
            }
        }

        // Save button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 120
            height: 32
            radius: root.metrics.radiusSM
            color: saveArea.containsMouse ? root.theme.accent : root.theme.surface
            border.color: root.theme.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Save Token"
                font.bold: true
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                color: saveArea.containsMouse ? root.theme.background : root.theme.accent
            }

            MouseArea {
                id: saveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }

        // Security assurance
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Saved to ~/.config/beeper-relay/token (mode 0600, local only)."
            font.family: root.theme.fontFamily
            font.pixelSize: 10
            color: root.theme.textSecondary
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }

    function submit() {
        var val = tokenInput.text.trim();
        if (val.length === 0) return;
        root.saveToken(val);
    }

    function focusInput() {
        tokenInput.forceActiveFocus();
    }
}
