import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "components"
import "components/KeyHintsHelper.js" as HintsHelper
import "models"
import "services"
import "theme"

FocusScope {
    id: root

    property bool open: false
    property int selectedIndex: -1
    property bool helpExpanded: false

    signal requestClose()
    signal requestOpenInBeeper(string chatId)

    implicitWidth: 400
    implicitHeight: root.drawerHeight

    property int drawerHeight: 300
    readonly property int minDrawerHeight: 220
    readonly property int maxDrawerHeight: 700
    readonly property int heightStep: 50

    Behavior on drawerHeight {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

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
    property bool hidePinned: false

    readonly property bool needsOnboarding: beeperService.tokenLoaded && !beeperService.hasToken
    readonly property var visibleChats: getVisibleChats(triageModel.chats, root.dismissedChatIds, root.hidePinned)
    readonly property bool inConversation: triageModel.activeChatId !== ""
    readonly property bool hasError: !needsOnboarding && (triageModel.error !== "")
    readonly property bool hasChats: Boolean(root.visibleChats && root.visibleChats.length > 0)
    readonly property bool isInboxEmpty: !needsOnboarding && !hasError && !hasChats
    readonly property var currentChat: findChatById(triageModel.chats, triageModel.activeChatId)

    function getVisibleChats(chats, dismissed, hidePinned) {
        if (!chats) return [];
        var out = [];
        for (var i = 0; i < chats.length; i++) {
            var c = chats[i];
            if (root.isChatVisible(c, dismissed, hidePinned)) out.push(c);
        }
        return out;
    }

    function isChatVisible(c, dismissed, hidePinned) {
        if (!c) return false;
        if (dismissed[c.id]) return false;
        if (hidePinned && c.isPinned) return false;
        return true;
    }

    function isChatPinned(chatId) {
        var c = findChatById(triageModel.chats, chatId);
        return Boolean(c && c.isPinned);
    }

    function togglePinCurrent() {
        var id = root.resolveChatId("");
        if (!id) return;
        triageModel.togglePin(id);
    }

    function toggleHidePinned() {
        root.hidePinned = !root.hidePinned;
        root.clampSelectedIndex();
    }

    function handlePinKey(event) {
        if (event.modifiers & Qt.ControlModifier) {
            root.toggleHidePinned();
        } else {
            root.togglePinCurrent();
        }
        event.accepted = true;
    }

    function growHeight() {
        var target = Math.min(root.maxDrawerHeight, root.drawerHeight + root.heightStep);
        if (target !== root.drawerHeight) root.drawerHeight = target;
    }

    function shrinkHeight() {
        var target = Math.max(root.minDrawerHeight, root.drawerHeight - root.heightStep);
        if (target !== root.drawerHeight) root.drawerHeight = target;
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
        } else if (root.selectedIndex < 0) {
            root.selectedIndex = 0;
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
            if (root.quickReplyOpen) root.closeQuickReply();
            else root.releaseInputs();
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
            root.releaseInputs();
            triageModel.closeChat();
        } else {
            root.requestClose();
        }
    }

    function handleReadOrRefresh(event) {
        if (event.modifiers & Qt.ControlModifier) {
            triageModel.refresh();
        } else {
            var cid = root.resolveChatId("");
            if (!root.isChatPinned(cid)) root.dismissChat(cid);
            triageModel.markActiveChatRead(cid);
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
        quickReplyComposer.focusInput();
    }

    function releaseInputs() {
        quickReplyComposer.blur();
        if (conversationView && typeof conversationView.blurComposer === "function") {
            conversationView.blurComposer();
        }
        root.forceActiveFocus();
    }

    function closeQuickReply() {
        quickReplyComposer.text = "";
        quickReplyComposer.blur();
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
        if (!triageModel) return;
        triageModel.quickReply(chatId, text);
    }

    function submitQuickReply(text) {
        var chat = root.quickReplyChat;
        if (!chat) return;
        var t = (text || "").trim();
        if (t.length === 0) return;
        root.dispatchQuickReply(chat.id, t);
        if (!root.isChatPinned(chat.id)) root.dismissChat(chat.id);
        root.closeQuickReply();
    }

    function isQuitKey(key) {
        return key === Qt.Key_Escape || key === Qt.Key_Q;
    }

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter;
    }

    function isListOpenKey(key) {
        return key === Qt.Key_O || root.isActivateKey(key);
    }

    function routeCommonKey(event) {
        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_Down)) {
            root.growHeight();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_Up)) {
            root.shrinkHeight();
            event.accepted = true;
        } else if (root.isQuitKey(event.key)) {
            root.handleEscape();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            root.handleReadOrRefresh(event);
            event.accepted = true;
        } else if (event.key === Qt.Key_P) {
            root.handlePinKey(event);
            event.accepted = true;
        } else if (event.key === Qt.Key_H) {
            root.toggleHidePinned();
            event.accepted = true;
        } else if (event.key === Qt.Key_Question || event.text === "?") {
            root.helpExpanded = !root.helpExpanded;
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
            var chat = root.getSelectedChat();
            root.openInBeeper(chat ? chat.id : "");
            event.accepted = true;
        } else if (event.key === Qt.Key_I) {
            root.openQuickReply();
            event.accepted = true;
        }
    }

    function routeListKey(event) {
        root.handleListNav(event);
        if (event.accepted) return;
        if (root.isListOpenKey(event.key)) {
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
        if (root.needsOnboarding) {
            if (event.key === Qt.Key_Escape) {
                root.handleEscape();
                event.accepted = true;
            }
            return;
        }
        if (root.quickReplyOpen) {
            if (event.key === Qt.Key_Escape) {
                root.closeQuickReply();
                event.accepted = true;
            }
            return;
        }
        if (root.inConversation && conversationView.isComposerFocused) {
            if (event.key === Qt.Key_Escape) {
                root.releaseInputs();
                event.accepted = true;
                return;
            }
            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_Down)) {
                root.growHeight();
                event.accepted = true;
                return;
            }
            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_Up)) {
                root.shrinkHeight();
                event.accepted = true;
                return;
            }
            return;
        }
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
                    text: root.hidePinned ? "Relay · pins hidden" : "Relay"
                    color: theme.textPrimary
                    font.family: theme.fontFamily
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
                        font.family: theme.fontFamily
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
                        root.releaseInputs();
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
                            font.family: theme.fontFamily
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
                        var cid = triageModel.activeChatId;
                        root.releaseInputs();
                        if (!root.isChatPinned(cid)) root.dismissChat(cid);
                        triageModel.markActiveChatRead(cid);
                    }

                    Text {
                        id: markReadText
                        anchors.centerIn: parent
                        text: "Mark read"
                        color: theme.accent
                        font.family: theme.fontFamily
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
                        font.family: theme.fontFamily
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

                OnboardingView {
                    id: onboardingView
                    anchors.fill: parent
                    visible: root.needsOnboarding
                    onSaveToken: function(tok) {
                        beeperService.saveToken(tok);
                    }
                }

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
                    visible: !root.needsOnboarding && !root.hasError && root.hasChats
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
                busy: triageModel.sending
                onRequestMarkRead: {
                    var cid = triageModel.activeChatId;
                    root.releaseInputs();
                    if (!root.isChatPinned(cid)) root.dismissChat(cid);
                    triageModel.markActiveChatRead(cid);
                }
                onRequestOpenInBeeper: {
                    root.openInBeeper(triageModel.activeChatId);
                }
                onSubmitReply: function(text) {
                    triageModel.submitReply(text);
                    conversationView.scrollToBottom();
                    root.releaseInputs();
                }
            }
        }

        // Quick Reply Bar (uses Composer for unified styling, rounding, and text centering)
        Item {
            id: quickReplyBar
            anchors.bottom: footerBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: metrics.spacingMD
            anchors.rightMargin: metrics.spacingMD
            anchors.bottomMargin: metrics.spacingSM
            implicitHeight: quickReplyComposer.implicitHeight
            visible: root.quickReplyOpen && !root.inConversation

            Composer {
                id: quickReplyComposer
                anchors.fill: parent
                prefixText: root.quickReplyChat ? (root.quickReplyChat.title + ":") : ""
                placeholderText: "Reply…"
                theme: root.theme
                metrics: root.metrics
                onSubmit: function(text) {
                    root.submitQuickReply(text);
                }
                onEscapePressed: {
                    root.closeQuickReply();
                }
                onGrowHeightRequested: {
                    root.growHeight();
                }
                onShrinkHeightRequested: {
                    root.shrinkHeight();
                }
            }
        }

        // Footer Bar (Key hints)
        Item {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: metrics.spacingMD
            anchors.rightMargin: metrics.spacingMD
            height: root.helpExpanded ? Math.max(24, footerText.implicitHeight + 4) : 24

            Text {
                id: footerText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: root.helpExpanded ? Text.AlignTop : Text.AlignVCenter
                text: root.formattedHints
                font.family: theme.fontFamily
                font.pixelSize: 11
                textFormat: Text.StyledText
                wrapMode: root.helpExpanded ? Text.WordWrap : Text.NoWrap
                elide: root.helpExpanded ? Text.ElideNone : Text.ElideRight
            }
        }
    }

    readonly property string formattedHints: formatHints(root.activeHints)

    function formatHints(hints) {
        return HintsHelper.formatHints(hints, root.helpExpanded, theme.textSecondary, theme.textPrimary);
    }

    function getHints() {
        if (root.needsOnboarding) return getOnboardingHints();
        if (root.quickReplyOpen) return getQuickReplyHints();
        if (root.inConversation) return getConversationHints();
        if (root.hasError) return getErrorHints();
        return getListHints();
    }

    function getOnboardingHints() {
        return [
            { key: "Enter", label: "save" },
            { key: "Esc", label: "close" }
        ];
    }

    function getQuickReplyHints() {
        return [
            { key: "Enter", label: "send" },
            { key: "Esc", label: "cancel" }
        ];
    }

    function getErrorHints() {
        return [
            { key: "r", label: "retry" },
            { key: "q", label: "close" }
        ];
    }

    function getConversationHints() {
        if (!root.helpExpanded) {
            return [
                { key: "j/k", label: "scroll" },
                { key: "r", label: "read" },
                { key: "i", label: "reply" },
                { key: "?", label: "more" }
            ];
        }
        return [
            { key: "j/k", label: "scroll" },
            { key: "i", label: "reply" },
            { key: "p", label: "pin" },
            { key: "C-j/k", label: "size" },
            { key: "r", label: "read" },
            { key: "b", label: "beeper" },
            { key: "q", label: "back" },
            { key: "?", label: "less" }
        ];
    }

    function getListHints() {
        if (!root.helpExpanded) {
            return [
                { key: "j/k", label: "nav" },
                { key: "o", label: "open" },
                { key: "r", label: "read" },
                { key: "i", label: "reply" },
                { key: "?", label: "more" }
            ];
        }
        return [
            { key: "j/k", label: "nav" },
            { key: "o", label: "open" },
            { key: "i", label: "reply" },
            { key: "p", label: "pin" },
            { key: "h", label: root.hidePinned ? "show pinned" : "hide pinned" },
            { key: "C-j/k", label: "size" },
            { key: "r", label: "read" },
            { key: "b", label: "beeper" },
            { key: "q", label: "close" },
            { key: "?", label: "less" }
        ];
    }
}
