import QtQuick
import Quickshell
import Quickshell.Io
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

    Component.onCompleted: {
        tokenProc.running = true;
    }

    Process {
        id: tokenProc
        command: ["cat", (Quickshell.env("HOME") || "/home/denial") + "/.config/beeper-relay/token"]
        stdout: StdioCollector {
            id: tokenOut
            waitForEnd: true
            onStreamFinished: {
                root.handleTokenLoaded(tokenOut.text);
            }
        }
    }

    function handleTokenLoaded(raw) {
        var token = (raw || "").trim();
        if (token === "") return;
        root.authToken = token;
        if (root.status === "error") {
            root.refreshUnread();
        }
    }

    property int pollInterval: 5000
    property int backoffInterval: 1000

    property bool isRefreshing: false
    property bool hasPendingRefresh: false
    property var loadingChats: ({})
    property var recentlyMarkedRead: ({})

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
        root.executeHttp("GET", "/v1/chats/search?unreadOnly=true&type=any&limit=200", null,
            root.onUnreadSearchSuccess, root.onRefreshFailure);
    }

    function onUnreadSearchSuccess(data) {
        var rawChats = root.itemsOf(data, "chats");
        if (root.hasVaultChat(rawChats)) {
            root.onRefreshSuccess(rawChats);
        } else {
            root.fetchVaultChat(rawChats);
        }
    }

    function hasVaultChat(rawChats) {
        if (!rawChats) return false;
        for (var i = 0; i < rawChats.length; i++) {
            if (TM.isVaultChat(rawChats[i])) return true;
        }
        return false;
    }

    function fetchVaultChat(rawChats) {
        root.executeHttp("GET", "/v1/chats/search?query=VAULT&limit=5", null, function(vaultData) {
            var vaultChats = root.itemsOf(vaultData, "chats");
            root.onRefreshSuccess(rawChats.concat(vaultChats));
        }, function(err) {
            root.onRefreshSuccess(rawChats);
        });
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

    function recordRecentlyMarkedRead(chatId) {
        var copy = Object.assign({}, root.recentlyMarkedRead);
        copy[chatId] = Date.now();
        root.recentlyMarkedRead = copy;
    }

    function isRecentlyMarkedRead(id) {
        var t = root.recentlyMarkedRead[id];
        if (!t) return false;
        return (Date.now() - t <= 10000);
    }

    function removeOrZeroChat(chatId) {
        var updated = [];
        for (var i = 0; i < root.chats.length; i++) {
            var c = root.chats[i];
            if (!c) continue;
            if (c.id === chatId) {
                if (TM.isVaultChat(c)) {
                    updated.push(Object.assign({}, c, { unreadCount: 0 }));
                }
            } else {
                updated.push(c);
            }
        }
        root.chats = updated;
    }

    function shouldSkipChat(seen, item) {
        if (!item || !item.id) return true;
        if (seen[item.id]) return true;
        seen[item.id] = true;
        return false;
    }

    function appendVaultIfMatch(list, item) {
        if (!TM.isVaultChat(item)) return;
        var zeroed = Object.assign({}, item, { unreadCount: 0 });
        list.push(TM.normalizeChat(zeroed));
    }

    function appendUniqueChat(list, seen, item) {
        if (root.shouldSkipChat(seen, item)) return;
        if (root.isRecentlyMarkedRead(item.id)) {
            root.appendVaultIfMatch(list, item);
            return;
        }
        list.push(TM.normalizeChat(item));
    }

    function processRefreshedChats(rawList) {
        var eligible = TM.filterEligibleChats(rawList);
        var normalized = [];
        var seen = {};
        for (var i = 0; i < eligible.length; i++) {
            root.appendUniqueChat(normalized, seen, eligible[i]);
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
        var sorted = TM.sortMessages(msgs);
        root.applyLoadedMessages(chatId, sorted);
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
        root.recordRecentlyMarkedRead(chatId);
        root.removeOrZeroChat(chatId);
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/read";
        var payload = messageId ? { messageID: messageId, messageId: messageId } : {};
        root.executeHttp("POST", path, payload, function(data) {
            root.onMarkReadSuccess(chatId);
        }, function(err) {
            root.onMarkReadFailure(err);
        });
    }

    function onMarkReadSuccess(chatId) {
        root.updateChatUnreadZero(chatId);
        root.removeOrZeroChat(chatId);
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

