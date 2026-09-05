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

    property bool quickReplyOpen: false
    property var quickReplyChat: null
    property var dismissedChatIds: ({})

    readonly property var visibleChats: getVisibleChats(triageModel.chats, root.dismissedChatIds)
    readonly property bool inConversation: triageModel.activeChatId !== ""
    readonly property bool hasError: triageModel.error !== ""
    readonly property bool hasChats: Boolean(root.visibleChats && root.visibleChats.length > 0)
    readonly property bool isInboxEmpty: !hasError && !hasChats
    readonly property var currentChat: findChatById(triageModel.chats, triageModel.activeChatId)

    function getVisibleChats(chats, dismissed) {
        if (!chats) return [];
        var out = [];
        for (var i = 0; i < chats.length; i++) {
            var c = chats[i];
            if (c && !dismissed[c.id]) {
                out.push(c);
            }
        }
        return out;
    }

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
        var count = root.visibleChats ? root.visibleChats.length : 0;
        if (root.selectedIndex < 0 && count > 0) {
            root.selectedIndex = 0;
        }
    }

    function clampSelectedIndex() {
        var count = root.visibleChats ? root.visibleChats.length : 0;
        if (count === 0) {
            root.selectedIndex = -1;
        } else if (root.selectedIndex >= count) {
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
        var list = root.visibleChats;
        if (!list || root.selectedIndex < 0) return null;
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
        var count = root.visibleChats ? root.visibleChats.length : 0;
        if (count <= 0) {
            root.selectedIndex = -1;
            return;
        }
        var next = root.selectedIndex + delta;
        root.selectedIndex = Math.max(0, Math.min(next, count - 1));
    }

    function handleEscape() {
        if (root.quickReplyOpen) {
            root.closeQuickReply();
            return;
        }
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

    function resolveChatId(chatId) {
        if (chatId) return chatId;
        var sel = root.getSelectedChat();
        if (sel && sel.id) return sel.id;
        return triageModel.activeChatId || "";
    }

    function openBeeperUrl(targetId) {
        var targetUrl = targetId ? ("beeper://chat/" + encodeURIComponent(targetId)) : "beeper://";
        Qt.openUrlExternally(targetUrl);
    }

    function openInBeeper(chatId) {
        var targetId = root.resolveChatId(chatId);
        root.requestOpenInBeeper(targetId);
        if (typeof triageModel.openInBeeper === "function") {
            triageModel.openInBeeper(targetId);
        } else {
            root.openBeeperUrl(targetId);
        }
        root.requestClose();
    }

    function focusComposer() {
        var item = conversationView;
        if (!item) return;
        if (typeof item.focusComposer === "function") {
            item.focusComposer();
        }
    }

    function openQuickReply() {
        var chat = root.getSelectedChat();
        if (!chat) return;
        root.quickReplyChat = chat;
        root.quickReplyOpen = true;
        quickReplyInput.forceActiveFocus();
    }

    function closeQuickReply() {
        root.quickReplyOpen = false;
        root.quickReplyChat = null;
        root.forceActiveFocus();
    }

    function dismissChat(chatId) {
        if (!chatId) return;
        var map = Object.assign({}, root.dismissedChatIds);
        map[chatId] = true;
        root.dismissedChatIds = map;
        root.clampSelectedIndex();
    }

    function dispatchQuickReply(chatId, text) {
        if (!beeperService) return;
        beeperService.sendText(chatId, text);
        beeperService.markRead(chatId, null);
    }

    function submitQuickReply(text) {
        var chat = root.quickReplyChat;
        if (!chat) return;
        var t = (text || "").trim();
        if (t.length === 0) return;
        root.dispatchQuickReply(chat.id, t);
        root.dismissChat(chat.id);
        root.closeQuickReply();
    }

    function handleQuickReplyKey(event) {
        if (event.key === Qt.Key_Escape) {
            quickReplyInput.text = "";
            root.closeQuickReply();
            event.accepted = true;
        } else if (root.isActivateKey(event.key)) {
            var msg = quickReplyInput.text;
            quickReplyInput.text = "";
            root.submitQuickReply(msg);
            event.accepted = true;
        }
    }

    function isQuitKey(key) {
        return key === Qt.Key_Escape || key === Qt.Key_Q;
    }

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_O;
    }

    function routeCommonKey(event) {
        if (root.isQuitKey(event.key)) {
            root.handleEscape();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            root.handleReadOrRefresh(event);
            event.accepted = true;
        }
    }

    function isNavDown(key) {
        return key === Qt.Key_J || key === Qt.Key_Down;
    }

    function isNavUp(key) {
        return key === Qt.Key_K || key === Qt.Key_Up;
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

    function handleListAction(event) {
        if (event.key === Qt.Key_B) {
            root.openInBeeper("");
            event.accepted = true;
        } else if (event.key === Qt.Key_I) {
            root.openQuickReply();
            event.accepted = true;
        }
    }

    function routeListKey(event) {
        root.handleListNav(event);
        if (event.accepted) return;
        if (root.isActivateKey(event.key)) {
            root.activateCurrentChat();
            event.accepted = true;
            return;
        }
        root.handleListAction(event);
    }

    function handleConvNav(event) {
        if (root.isNavDown(event.key)) {
            conversationView.scrollDown();
            event.accepted = true;
        } else if (root.isNavUp(event.key)) {
            conversationView.scrollUp();
            event.accepted = true;
        }
    }

    function routeConvKey(event) {
        root.handleConvNav(event);
        if (event.accepted) return;
        if (event.key === Qt.Key_I || event.key === Qt.Key_C) {
            root.focusComposer();
            event.accepted = true;
        } else if (event.key === Qt.Key_B) {
            root.openInBeeper(triageModel.activeChatId);
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
                    visible: Boolean(root.currentChat && root.currentChat.unreadCount > 0)
                    implicitWidth: markReadText.implicitWidth + metrics.spacingSM
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        triageModel.markActiveChatRead();
                    }

                    Text {
                        id: markReadText
                        anchors.centerIn: parent
                        text: "Mark read"
                        color: theme.accent
                        font.pixelSize: 12
                    }
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
            anchors.bottom: (root.quickReplyOpen && !root.inConversation) ? quickReplyBar.top : footerBar.top
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
                    chats: root.visibleChats
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

        // Quick Reply Bar
        Rectangle {
            id: quickReplyBar
            anchors.bottom: footerBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            visible: root.quickReplyOpen && !root.inConversation
            color: theme.surfaceRaised
            border.color: theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: metrics.spacingMD
                anchors.rightMargin: metrics.spacingMD
                spacing: metrics.spacingSM

                Text {
                    text: root.quickReplyChat ? (root.quickReplyChat.title + ":") : ""
                    color: theme.accent
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: 100
                }

                TextInput {
                    id: quickReplyInput
                    Layout.fillWidth: true
                    color: theme.textPrimary
                    font.pixelSize: 13
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        visible: parent.text.length === 0
                        text: "Reply… (Enter to send, Esc to cancel)"
                        color: theme.textSecondary
                        font.pixelSize: 13
                    }

                    Keys.onPressed: function(event) {
                        root.handleQuickReplyKey(event);
                    }
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
        if (root.quickReplyOpen) {
            return [
                { key: "Enter", label: "send" },
                { key: "Esc", label: "cancel" }
            ];
        }
        if (root.inConversation) {
            return [
                { key: "j/k", label: "scroll" },
                { key: "i", label: "reply" },
                { key: "r", label: "read" },
                { key: "b", label: "beeper" },
                { key: "q", label: "back" }
            ];
        }
        if (root.hasError) {
            return [
                { key: "r", label: "retry" },
                { key: "q", label: "close" }
            ];
        }
        return [
            { key: "j/k", label: "nav" },
            { key: "o", label: "open" },
            { key: "i", label: "reply" },
            { key: "r", label: "read" },
            { key: "b", label: "beeper" },
            { key: "q", label: "close" }
        ];
    }
}
