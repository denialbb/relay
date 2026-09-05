import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "components"
import "models"
import "services"
import "theme"

FocusScope {
    id: root

    property bool open: false
    property int selectedIndex: -1

    signal requestClose()
    signal requestOpenInBeeper(string chatId)

    implicitWidth: 400
    implicitHeight: 600

    focus: true

    RelayTheme {
        id: theme
    }

    RelayMetrics {
        id: metrics
    }

    BeeperService {
        id: beeperService
    }

    TriageModel {
        id: triageModel
        service: beeperService
    }

    readonly property bool inConversation: triageModel.activeChatId !== ""
    readonly property bool hasError: triageModel.error !== ""
    readonly property bool hasChats: Boolean(triageModel.chats && triageModel.chats.length > 0)
    readonly property bool isInboxEmpty: !hasError && !hasChats
    readonly property var currentChat: findChatById(triageModel.chats, triageModel.activeChatId)

    function findChatById(list, id) {
        if (!list) return null;
        for (var i = 0; i < list.length; i++) {
            var c = list[i];
            if (c && c.id === id) return c;
        }
        return null;
    }

    function open(payloadJson) {
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    onOpenChanged: {
        handleOpenChanged();
    }

    function handleOpenChanged() {
        if (root.open) {
            root.forceActiveFocus();
            triageModel.refresh();
            initSelection();
        }
    }

    function initSelection() {
        var count = triageModel.chats ? triageModel.chats.length : 0;
        if (root.selectedIndex < 0 && count > 0) {
            root.selectedIndex = 0;
        }
    }

    function clampSelectedIndex() {
        var count = triageModel.chats ? triageModel.chats.length : 0;
        if (count === 0) {
            root.selectedIndex = -1;
            return;
        }
        if (root.selectedIndex < 0) {
            root.selectedIndex = 0;
            return;
        }
        if (root.selectedIndex >= count) {
            root.selectedIndex = count - 1;
        }
    }

    Connections {
        target: triageModel
        function onChatsChanged() {
            root.clampSelectedIndex();
        }
    }

    function getSelectedChat() {
        var list = triageModel.chats;
        if (!list) return null;
        if (root.selectedIndex < 0) return null;
        if (root.selectedIndex >= list.length) return null;
        return list[root.selectedIndex];
    }

    function activateCurrentChat() {
        var chat = getSelectedChat();
        if (chat) {
            triageModel.selectChat(chat.id);
        }
    }

    function navigateChat(delta) {
        var count = triageModel.chats ? triageModel.chats.length : 0;
        if (count <= 0) {
            root.selectedIndex = -1;
            return;
        }
        var next = root.selectedIndex + delta;
        root.selectedIndex = Math.max(0, Math.min(next, count - 1));
    }

    function handleEscape() {
        if (triageModel.activeChatId !== "") {
            triageModel.closeChat();
        } else {
            root.requestClose();
        }
    }

    function handleReadOrRefresh(event) {
        if (event.modifiers & Qt.ControlModifier) {
            triageModel.refresh();
        } else {
            triageModel.markActiveChatRead();
        }
    }

    function openInBeeper(chatId) {
        var targetId = chatId || triageModel.activeChatId || "";
        root.requestOpenInBeeper(targetId);
        if (typeof triageModel.openInBeeper === "function") {
            triageModel.openInBeeper(targetId);
        }
        var targetUrl = targetId !== "" ? ("beeper://chat/" + encodeURIComponent(targetId)) : "beeper://";
        Qt.openUrlExternally(targetUrl);
        root.requestClose();
    }

    function focusComposer() {
        var item = conversationView;
        if (!item) return;
        if (typeof item.focusComposer === "function") {
            item.focusComposer();
        }
    }

    function routeCommonKey(event) {
        if (event.key === Qt.Key_Escape) {
            handleEscape();
            event.accepted = true;
        } else if (event.key === Qt.Key_O) {
            openInBeeper(triageModel.activeChatId);
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            handleReadOrRefresh(event);
            event.accepted = true;
        }
    }

    function isNavDown(key) {
        return key === Qt.Key_J || key === Qt.Key_Down;
    }

    function isNavUp(key) {
        return key === Qt.Key_K || key === Qt.Key_Up;
    }

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter;
    }

    function handleListNav(event) {
        if (isNavDown(event.key)) {
            navigateChat(1);
            event.accepted = true;
        } else if (isNavUp(event.key)) {
            navigateChat(-1);
            event.accepted = true;
        }
    }

    function routeListKey(event) {
        handleListNav(event);
        if (event.accepted) return;
        if (isActivateKey(event.key)) {
            activateCurrentChat();
            event.accepted = true;
        }
    }

    function routeConvKey(event) {
        if (event.key === Qt.Key_C) {
            focusComposer();
            event.accepted = true;
        }
    }

    function routeKey(event) {
        routeCommonKey(event);
        if (event.accepted) return;
        if (root.inConversation) {
            routeConvKey(event);
        } else {
            routeListKey(event);
        }
    }

    Keys.onPressed: function(event) {
        routeKey(event);
    }
    readonly property var activeHints: getHints()

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: theme.background
        radius: metrics.radiusMD
        clip: true

        // Header Bar
        Rectangle {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: metrics.barHeight
            color: theme.surface
            border.color: theme.border
            border.width: 1

            // List mode header
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: metrics.spacingMD
                anchors.rightMargin: metrics.spacingMD
                visible: !root.inConversation

                Text {
                    text: "Relay"
                    color: theme.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: triageModel.unreadTotal > 0
                    radius: metrics.radiusSM
                    color: theme.accent
                    implicitWidth: badgeText.implicitWidth + metrics.spacingSM
                    implicitHeight: badgeText.implicitHeight + metrics.spacingXS
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: String(triageModel.unreadTotal)
                        color: theme.background
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // Conversation mode header
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: metrics.spacingMD
                anchors.rightMargin: metrics.spacingMD
                visible: root.inConversation

                MouseArea {
                    Layout.fillHeight: true
                    implicitWidth: backRow.implicitWidth
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        triageModel.closeChat();
                    }

                    Row {
                        id: backRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: metrics.spacingXS

                        Text {
                            text: "←"
                            color: theme.accent
                            font.pixelSize: 14
                        }

                        Text {
                            text: root.currentChat && root.currentChat.title ? root.currentChat.title : "Chat"
                            color: theme.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                MouseArea {
                    Layout.fillHeight: true
                    implicitWidth: beeperText.implicitWidth + metrics.spacingSM
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.openInBeeper(triageModel.activeChatId);
                    }

                    Text {
                        id: beeperText
                        anchors.centerIn: parent
                        text: "Beeper ↗"
                        color: theme.accent
                        font.pixelSize: 12
                    }
                }
            }
        }

        // Content Area
        Item {
            id: contentArea
            anchors.top: headerBar.bottom
            anchors.bottom: footerBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            clip: true

            // Chat list / empty / error container
            Item {
                id: listContainer
                anchors.fill: parent
                visible: !root.inConversation

                ErrorState {
                    id: errorState
                    anchors.fill: parent
                    visible: root.hasError
                    error: triageModel.error
                    isRefreshing: triageModel.isRefreshing
                    onRetry: {
                        triageModel.refresh();
                    }
                }

                EmptyState {
                    id: emptyState
                    anchors.fill: parent
                    visible: root.isInboxEmpty
                }

                ChatList {
                    id: chatList
                    anchors.fill: parent
                    visible: !root.hasError && root.hasChats
                    chats: triageModel.chats
                    selectedIndex: root.selectedIndex
                    onChatActivated: function(index) {
                        root.selectedIndex = index;
                        root.activateCurrentChat();
                    }
                }
            }

            // Conversation view
            ConversationView {
                id: conversationView
                anchors.fill: parent
                visible: root.inConversation
                chat: root.currentChat
                messages: triageModel.activeMessages
                onRequestMarkRead: {
                    triageModel.markActiveChatRead();
                }
                onRequestOpenInBeeper: {
                    root.openInBeeper(triageModel.activeChatId);
                }
            }
        }

        // Footer Bar (Key hints)
        Rectangle {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            color: theme.surface
            border.color: theme.border
            border.width: 1

            KeyHints {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: metrics.spacingMD
                hints: root.activeHints
                textColor: theme.textPrimary
                dimColor: theme.textSecondary
                badgeColor: theme.surfaceRaised
                badgeRadius: metrics.radiusSM
            }
        }
    }

    function getHints() {
        if (root.inConversation) {
            return [
                { key: "c", label: "reply" },
                { key: "r", label: "mark read" },
                { key: "o", label: "beeper" },
                { key: "Esc", label: "back" }
            ];
        }
        if (root.hasError) {
            return [
                { key: "r", label: "retry" },
                { key: "Esc", label: "close" }
            ];
        }
        return [
            { key: "j / k", label: "navigate" },
            { key: "Enter", label: "select" },
            { key: "r", label: "mark read" },
            { key: "o", label: "beeper" },
            { key: "Esc", label: "close" }
        ];
    }
}
