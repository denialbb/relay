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

    function markActiveChatRead() {
        if (!root.activeChatId) return;
        var msgId = root.getLatestMessageId();
        if (root.service) {
            root.service.markRead(root.activeChatId, msgId);
        }
    }

    function getLatestMessageId() {
        var msgs = root.activeMessages;
        if (!msgs || msgs.length === 0) return null;
        var last = msgs[msgs.length - 1];
        return last ? last.id : null;
    }

    function openInBeeper(chatId) {
        var targetId = chatId || root.activeChatId;
        var url = targetId ? ("beeper://chat/" + encodeURIComponent(targetId)) : "beeper://";
        Qt.openUrlExternally(url);
    }
}

