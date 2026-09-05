import QtQuick
import "../services"
import "TriageModel.js" as TM

Item {
    id: root

    property var service: fallbackService
    property var chats: service ? service.chats : []
    property string activeChatId: ""
    property var activeMessages: []
    property int unreadTotal: chats ? TM.calculateUnreadTotal(chats) : 0
    property string status: service ? service.status : "idle"
    property string error: service ? service.lastError : ""
    property bool isRefreshing: service ? service.isRefreshing : false

    BeeperService {
        id: fallbackService
    }

    Connections {
        target: root.service
        function onActiveChatChanged() {
            root.handleActiveChatChanged();
        }
    }

    function handleActiveChatChanged() {
        var chat = root.service ? root.service.activeChat : null;
        if (!chat) return;
        if (chat.id !== root.activeChatId) return;
        root.activeMessages = chat.messages ? chat.messages : [];
    }

    function selectChat(chatId) {
        if (!chatId) return;
        root.activeChatId = chatId;
        root.syncActiveMessages();
        if (root.service) {
            root.service.loadMessages(chatId);
        }
    }

    function syncActiveMessages() {
        var chat = root.service ? root.service.activeChat : null;
        if (!chat || chat.id !== root.activeChatId) {
            root.activeMessages = [];
            return;
        }
        root.activeMessages = chat.messages ? chat.messages : [];
    }

    function closeChat() {
        root.activeChatId = "";
        root.activeMessages = [];
    }

    function refresh() {
        if (root.service) {
            root.service.refreshUnread();
        }
    }

    // Layering: UI sets auth through the model, never directly on the service.
    function setAuthToken(token) {
        if (root.service) {
            root.service.authToken = (token || "").trim();
        }
    }

    function submitReply(text) {
        if (!root.activeChatId) return;
        if (!text || text.trim().length === 0) return;
        var localId = "local-" + Date.now();
        var pending = root.createPendingMessage(localId, text);
        root.activeMessages = TM.appendPendingMessage(root.activeMessages, pending);
        if (root.service) {
            root.service.sendText(root.activeChatId, text, localId);
        }
    }

    function createPendingMessage(localId, text) {
        return {
            id: localId,
            chatId: root.activeChatId,
            senderId: "me",
            senderName: "Me",
            timestamp: new Date().toISOString(),
            isMine: true,
            isUnread: false,
            kind: "text",
            text: text,
            sendState: "pending"
        };
    }

    function markActiveChatRead(chatId) {
        var targetId = root.resolveTargetChatId(chatId);
        if (!targetId) return;
        root.executeMarkRead(targetId);
    }

    function resolveTargetChatId(chatId) {
        if (chatId) return chatId;
        return root.activeChatId;
    }

    function executeMarkRead(targetId) {
        var isCurrent = (targetId === root.activeChatId);
        var msgId = isCurrent ? root.getLatestMessageId() : null;
        if (isCurrent) {
            root.closeChat();
        }
        if (root.service) {
            root.service.markRead(targetId, msgId);
        }
    }

    function quickReply(chatId, text) {
        if (!chatId || !text) return;
        if (root.service) {
            root.service.sendText(chatId, text);
            root.service.markRead(chatId, null);
        }
    }

    function getLatestMessageId() {
        var msgs = root.activeMessages;
        if (!msgs || msgs.length === 0) return null;
        var last = msgs[msgs.length - 1];
        return last ? last.id : null;
    }

    function findChat(chatId) {
        var list = root.chats;
        if (!list) return null;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].id === chatId) return list[i];
        }
        return null;
    }

    function buildBeeperUrl(chat) {
        if (!chat) return "beeper://focus";
        var p = chat.accountID || (chat.network ? chat.network.toLowerCase() : "");
        if (!p) return "beeper://focus";
        return "beeper://select-thread/" + encodeURIComponent(p) + "/" + encodeURIComponent(chat.id) + "?accountID=" + encodeURIComponent(p);
    }

    function openInBeeper(chatId) {
        var targetId = chatId || root.activeChatId;
        if (!targetId) {
            Qt.openUrlExternally("beeper://focus");
            return;
        }
        var chat = root.findChat(targetId);
        var url = root.buildBeeperUrl(chat);
        Qt.openUrlExternally(url);
    }
}

