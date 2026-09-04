import QtQuick
import Quickshell
import "../models/TriageModel.js" as TM

Item {
    id: root

    property string status: "idle"
    property var chats: []
    property var activeChat: null
    property string lastRefreshAt: ""
    property string lastError: ""
    property bool pollingActive: false

    property string baseUrl: "http://127.0.0.1:23373"
    property string authToken: ""
    property int pollInterval: 5000
    property int backoffInterval: 1000

    property bool isRefreshing: false
    property bool hasPendingRefresh: false
    property var loadingChats: ({})

    signal refreshStarted()
    signal refreshFinished()
    signal sendStarted(string chatId, string localMessageId)
    signal sendFinished(string chatId, string localMessageId)
    signal errorChanged()

    Timer {
        id: pollTimer
        interval: root.pollInterval
        repeat: true
        running: root.pollingActive
        onTriggered: {
            root.handlePollTrigger();
        }
    }

    function handlePollTrigger() {
        if (root.pollingActive) {
            root.refreshUnread();
        }
    }

    // ponytail: XHR is the only HTTP primitive in the QML runtime (no fetch),
    // so transport lives here; response-shape normalization is canonical in
    // BeeperApi.extractItems and mirrored below in itemsOf().
    function itemsOf(data, key) {
        if (data instanceof Array) return data;
        if (!data) return [];
        if (data.items instanceof Array) return data.items;
        if (data[key] instanceof Array) return data[key];
        return [];
    }

    function initialize() {
        var envToken = Quickshell.env("BEEPER_ACCESS_TOKEN");
        if (envToken && !root.authToken) {
            root.authToken = envToken.trim();
        }
        root.pollingActive = true;
        root.refreshUnread();
    }

    function stopPolling() {
        root.pollingActive = false;
    }

    function retry() {
        root.backoffInterval = 1000;
        root.lastError = "";
        root.refreshUnread();
    }

    function refreshUnread() {
        if (root.isRefreshing) {
            root.hasPendingRefresh = true;
            return;
        }
        root.startRefreshRequest();
    }

    function startRefreshRequest() {
        root.isRefreshing = true;
        if (root.status !== "ready") {
            root.status = "loading";
        }
        root.refreshStarted();
        root.executeHttp("GET", "/v1/chats/search?unreadOnly=true&type=any", null,
            root.onRefreshSuccess, root.onRefreshFailure);
    }

    function onRefreshSuccess(data) {
        root.isRefreshing = false;
        var rawChats = root.itemsOf(data, "chats");
        root.processRefreshedChats(rawChats);
        root.resetBackoff();
        root.status = "ready";
        root.lastRefreshAt = new Date().toISOString();
        root.refreshFinished();
        root.checkPendingRefresh();
    }

    function processRefreshedChats(rawList) {
        var eligible = TM.filterEligibleChats(rawList);
        var normalized = [];
        for (var i = 0; i < eligible.length; i++) {
            normalized.push(TM.normalizeChat(eligible[i]));
        }
        root.chats = TM.sortChats(normalized);
        root.syncActiveChat();
    }

    function syncActiveChat() {
        if (!root.activeChat) return;
        var found = root.findChat(root.activeChat.id);
        if (found) {
            root.updateActiveChatPreservingMessages(found);
        }
    }

    function updateActiveChatPreservingMessages(found) {
        var msgs = root.activeChat.messages || [];
        var loaded = root.activeChat.messagesLoaded;
        root.activeChat = Object.assign({}, found, {
            messages: msgs,
            messagesLoaded: loaded
        });
    }

    function findChat(chatId) {
        var list = root.chats;
        if (!list) return null;
        for (var i = 0; i < list.length; i++) {
            var c = list[i];
            if (c.id === chatId) return c;
        }
        return null;
    }

    function onRefreshFailure(err) {
        root.isRefreshing = false;
        root.lastError = TM.mapApiError(err);
        root.status = "error";
        root.errorChanged();
        root.applyBackoff();
        root.refreshFinished();
        root.checkPendingRefresh();
    }

    function checkPendingRefresh() {
        if (root.hasPendingRefresh) {
            root.hasPendingRefresh = false;
            root.refreshUnread();
        }
    }

    function resetBackoff() {
        root.backoffInterval = 1000;
        root.lastError = "";
        pollTimer.interval = root.pollInterval;
    }

    function applyBackoff() {
        pollTimer.interval = root.backoffInterval;
        var next = root.backoffInterval * 2;
        root.backoffInterval = Math.min(30000, next);
        if (root.pollingActive) {
            pollTimer.restart();
        }
    }

    function loadMessages(chatId) {
        if (!chatId) return;
        if (root.loadingChats[chatId]) return;
        root.startMessageLoad(chatId);
    }

    function startMessageLoad(chatId) {
        var loads = Object.assign({}, root.loadingChats);
        loads[chatId] = true;
        root.loadingChats = loads;
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/messages";
        root.executeHttp("GET", path, null, function(data) {
            root.onMessagesLoaded(chatId, data);
        }, function(err) {
            root.onMessagesError(chatId, err);
        });
    }

    function onMessagesLoaded(chatId, data) {
        root.finishMessageLoad(chatId);
        var raw = root.itemsOf(data, "messages");
        var msgs = [];
        for (var i = 0; i < raw.length; i++) {
            msgs.push(TM.normalizeMessage(raw[i]));
        }
        root.applyLoadedMessages(chatId, msgs);
    }

    function applyLoadedMessages(chatId, msgs) {
        var base = root.findChat(chatId);
        var chatObj = base ? Object.assign({}, base) : { id: chatId };
        chatObj.messages = msgs;
        chatObj.messagesLoaded = true;
        root.activeChat = chatObj;
    }

    function onMessagesError(chatId, err) {
        root.finishMessageLoad(chatId);
        root.lastError = TM.mapApiError(err);
        root.errorChanged();
    }

    function finishMessageLoad(chatId) {
        var loads = Object.assign({}, root.loadingChats);
        delete loads[chatId];
        root.loadingChats = loads;
    }

    function sendText(chatId, text, localMessageId) {
        if (!chatId) return;
        if (!text) return;
        var localId = localMessageId || ("local-" + Date.now());
        root.sendStarted(chatId, localId);
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/messages";
        root.executeHttp("POST", path, { text: text }, function(data) {
            root.onSendSuccess(chatId, localId, data);
        }, function(err) {
            root.onSendFailure(chatId, localId, err);
        });
    }

    function onSendSuccess(chatId, localId, data) {
        root.sendFinished(chatId, localId);
        if (root.activeChat && root.activeChat.id === chatId) {
            root.reconcileSentMessage(localId, data ? data.id : null);
        }
        root.refreshUnread();
    }

    function reconcileSentMessage(localId, remoteId) {
        var msgs = root.activeChat.messages;
        if (!msgs) return;
        var reconciled = TM.reconcilePendingMessage(msgs, {
            localId: localId,
            id: remoteId
        });
        root.activeChat = Object.assign({}, root.activeChat, { messages: reconciled });
    }

    function onSendFailure(chatId, localId, err) {
        root.sendFinished(chatId, localId);
        root.lastError = TM.mapApiError(err);
        root.errorChanged();
    }

    function markRead(chatId, messageId) {
        if (!chatId) return;
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/read";
        var payload = messageId ? { messageId: messageId } : {};
        root.executeHttp("POST", path, payload, function(data) {
            root.onMarkReadSuccess(chatId);
        }, function(err) {
            root.onMarkReadFailure(err);
        });
    }

    function onMarkReadSuccess(chatId) {
        root.updateChatUnreadZero(chatId);
        root.refreshUnread();
    }

    function updateChatUnreadZero(chatId) {
        if (root.activeChat && root.activeChat.id === chatId) {
            root.activeChat = Object.assign({}, root.activeChat, { unreadCount: 0 });
        }
    }

    function onMarkReadFailure(err) {
        root.lastError = TM.mapApiError(err);
        root.errorChanged();
    }

    function executeHttp(method, path, body, onSuccess, onFailure) {
        var xhr = new XMLHttpRequest();
        xhr.open(method, root.baseUrl + path, true);
        xhr.timeout = 10000;
        root.applyAuthHeader(xhr);
        root.applyContentTypeHeader(xhr, body);
        root.bindXhrEvents(xhr, onSuccess, onFailure);
        xhr.send(body ? JSON.stringify(body) : null);
    }

    function applyAuthHeader(xhr) {
        if (root.authToken) {
            xhr.setRequestHeader("Authorization", "Bearer " + root.authToken);
        }
    }

    function applyContentTypeHeader(xhr, body) {
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json");
        }
    }

    function bindXhrEvents(xhr, onSuccess, onFailure) {
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.handleXhrDone(xhr, onSuccess, onFailure);
            }
        };
        xhr.ontimeout = function() {
            onFailure({ code: "ETIMEDOUT" });
        };
        xhr.onerror = function() {
            onFailure({ code: "ECONNREFUSED" });
        };
    }

    function handleXhrDone(xhr, onSuccess, onFailure) {
        if (xhr.status >= 200 && xhr.status < 300) {
            root.parseXhrResponse(xhr.responseText, onSuccess, onFailure);
        } else {
            onFailure({ status: xhr.status });
        }
    }

    function parseXhrResponse(text, onSuccess, onFailure) {
        var parsed = null;
        try {
            parsed = text ? JSON.parse(text) : {};
        } catch (e) {
            onFailure({ invalidBody: true });
            return;
        }
        onSuccess(parsed);
    }
}

