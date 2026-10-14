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
    property int pollInterval: 15000
    property bool pollingActive: false

    property string baseUrl: "http://127.0.0.1:23373"
    property string configDir: (Quickshell.env("HOME") || "") + "/.config/beeper-relay"
    property bool tokenLoaded: false
    property bool hasToken: false

    Component.onCompleted: {
        tokenProc.running = true;
    }

    Process {
        id: tokenProc
        command: ["python3", Qt.resolvedUrl("beeper_bridge.py").toString().replace("file://", ""), "check_token"]
        stdout: StdioCollector {
            id: tokenOut
            waitForEnd: true
            onStreamFinished: {
                var parsed = null;
                try {
                    parsed = JSON.parse(tokenOut.text);
                } catch (e) {}
                
                if (parsed && parsed.has_token) {
                    root.hasToken = true;
                    if (root.status === "error") {
                        root.refreshUnread();
                    }
                } else {
                    root.hasToken = false;
                }
                root.tokenLoaded = true;
            }
        }
    }

    Component {
        id: saveTokenProcComponent
        Process {
            property string tokenString: ""
            command: ["python3", Qt.resolvedUrl("beeper_bridge.py").toString().replace("file://", ""), "save_token"]
            
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    root.initialize();
                    
                }
            }
            
            Component.onCompleted: {
                running = true;
                if (tokenString) {
                    write(tokenString.length.toString() + "\n" + tokenString);
                }
            }
        }
    }

    function saveToken(rawToken) {
        var token = (rawToken || "").trim();
        if (!token) return;
        saveTokenProcComponent.createObject(root, {
            tokenString: token
        });
    }

    function handleTokenLoaded(raw) {}

    property int backoffInterval: 1000

    property bool isRefreshing: false
    property bool hasPendingRefresh: false
    property var loadingChats: ({})
    property var recentlyMarkedRead: ({})
    property var localPins: ({})
    property var retainedPins: ({})
    property bool showMutedChats: false
    property bool showLowPriorityChats: false
    property var loadingPreviews: ({})
    property bool previewsEnabled: true
    property int sendsInFlight: 0
    property string pinsPath: root.configDir + "/pins.json"
    property bool restoringPins: false

    property bool pinnedSeeded: false

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

    // XHR is the only HTTP primitive in the QML runtime (no fetch),
    // so transport lives here; response-shape normalization is canonical in
    // BeeperApi.extractItems and mirrored below in itemsOf().
    function itemsOf(data, key) {
        return TM.extractItems(data, key);
    }

    FileView {
        id: pinsFile
        path: root.pinsPath
        printErrors: true
        atomicWrites: true
        onLoaded: {
            root.restorePins(pinsFile.text());
        }
    }

    onLocalPinsChanged: {
        root.savePins();
    }

    onRetainedPinsChanged: {
        root.savePins();
    }

    onShowMutedChatsChanged: {
        root.savePins();
    }

    onShowLowPriorityChatsChanged: {
        root.savePins();
    }

    function savePins() {
        if (root.restoringPins) return;
        pinsFile.setText(JSON.stringify({
            localPins: root.localPins,
            retainedPins: TM.stripPreviewsForStorage(root.retainedPins),
            showMutedChats: root.showMutedChats,
            showLowPriorityChats: root.showLowPriorityChats
        }));
    }

    function restorePins(raw) {
        var data = root.parsePins(raw);
        if (!data) return;
        var filtersChanged = root.showMutedChats !== data.showMutedChats
            || root.showLowPriorityChats !== data.showLowPriorityChats;
        root.restoringPins = true;
        root.localPins = data.localPins;
        root.retainedPins = data.retainedPins;
        root.showMutedChats = data.showMutedChats;
        root.showLowPriorityChats = data.showLowPriorityChats;
        root.restoringPins = false;
        root.restampPins();
        if (filtersChanged && root.status !== "idle") root.refreshUnread();
    }

    function parsePinsJson(raw) {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    function validPinsShape(data) {
        return Boolean(data && typeof data.localPins === "object" && typeof data.retainedPins === "object");
    }

    function parsePins(raw) {
        if (!raw) return null;
        var data = root.parsePinsJson(raw);
        if (!root.validPinsShape(data)) return null;
        return {
            localPins: data.localPins || {},
            retainedPins: data.retainedPins || {},
            showMutedChats: data.showMutedChats === true,
            showLowPriorityChats: data.showLowPriorityChats === true
        };
    }

    function initialize() {
        root.hasToken = true;
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
        root.seedPinnedChats();
    }

    function seedPinnedChats() {
        if (root.pinnedSeeded) return;
        root.pinnedSeeded = true;
        root.executeHttp("GET", "/v1/chats/search?type=any&limit=200", null, function(data) {
            root.applyPinnedSeed(data);
        }, function(err) {
            root.pinnedSeeded = false;
        });
    }

    function applyPinnedSeed(data) {
        var raw = root.itemsOf(data, "chats");
        var fresh = [];
        for (var i = 0; i < raw.length; i++) {
            var norm = root.stampPinnedChat(raw[i]);
            if (norm) fresh.push(norm);
        }
        if (fresh.length === 0) return;
        root.retainedPins = TM.refreshPinSnapshots(fresh, root.retainedPins, root.localPins);
        root.chats = root.withRetainedPins(root.chats);
    }

    function stampPinnedChat(item) {
        if (!item || !item.id || !item.isPinned) return null;
        var norm = TM.normalizeChat(item);
        if (root.localPins[item.id]) norm.isPinned = true;
        return norm;
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

    function shouldKeepAfterRead(c, chatId) {
        if (!c || c.id !== chatId) return false;
        if (TM.isVaultChat(c)) return true;
        return Boolean(c.isPinned || root.localPins[c.id]);
    }

    function syncRetainedPinRead(chatId, zeroed) {
        var snap = root.retainedPins ? root.retainedPins[chatId] : null;
        if (!snap) return;
        var copy = Object.assign({}, root.retainedPins);
        var prev = zeroed.preview || snap.preview;
        copy[chatId] = Object.assign({}, snap, { unreadCount: 0, preview: prev });
        root.retainedPins = copy;
    }

    function removeOrZeroChat(chatId) {
        var updated = [];
        for (var i = 0; i < root.chats.length; i++) {
            var c = root.chats[i];
            if (root.shouldKeepAfterRead(c, chatId)) {
                var zeroed = Object.assign({}, c, { unreadCount: 0 });
                updated.push(zeroed);
                root.syncRetainedPinRead(chatId, zeroed);
            } else if (c && c.id !== chatId) {
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
        var norm = TM.normalizeChat(item, root.findChat(item.id));
        if (root.localPins[item.id]) norm.isPinned = true;
        list.push(norm);
    }

    function processRefreshedChats(rawList) {
        var eligible = TM.filterEligibleChats(rawList, {
            showMutedChats: root.showMutedChats,
            showLowPriorityChats: root.showLowPriorityChats
        });
        var normalized = [];
        var seen = {};
        for (var i = 0; i < eligible.length; i++) {
            root.appendUniqueChat(normalized, seen, eligible[i]);
        }
        var fresh = TM.sortChats(normalized);
        root.updatePinSnapshots(fresh);
        root.chats = root.withRetainedPins(fresh);
        root.syncActiveChat();
        root.loadPreviews();
    }

    function updatePinSnapshots(fresh) {
        root.retainedPins = TM.refreshPinSnapshots(fresh, root.retainedPins, root.localPins);
    }

    function withRetainedPins(fresh) {
        return TM.withRetainedPins(fresh, root.retainedPins);
    }

    function togglePin(chatId) {
        if (!chatId) return;
        var pins = Object.assign({}, root.localPins);
        if (pins[chatId]) delete pins[chatId];
        else pins[chatId] = true;
        root.localPins = pins;
        var kept = Object.assign({}, root.retainedPins);
        if (pins[chatId]) {
            var c = root.findChat(chatId);
            if (c) kept[chatId] = c;
        } else {
            delete kept[chatId];
        }
        root.retainedPins = kept;
        root.restampPins();
    }

    function restampPins() {
        var out = [];
        for (var i = 0; i < root.chats.length; i++) {
            var c = root.chats[i];
            if (!c) continue;
            if (root.localPins[c.id] && !c.isPinned) {
                c = Object.assign({}, c, { isPinned: true });
            }
            out.push(c);
        }
        root.chats = TM.sortChats(out);
        root.loadPreviews();
    }

    function shouldLoadPreview(c) {
        return Boolean(c && c.id && !c.preview);
    }

    function loadPreviews() {
        if (!root.previewsEnabled) return;
        for (var i = 0; i < root.chats.length; i++) {
            if (root.shouldLoadPreview(root.chats[i])) root.loadPreview(root.chats[i].id);
        }
    }

    function loadPreview(chatId) {
        if (!chatId) return;
        if (root.loadingPreviews[chatId]) return;
        var loads = Object.assign({}, root.loadingPreviews);
        loads[chatId] = true;
        root.loadingPreviews = loads;
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/messages";
        root.executeHttp("GET", path, null, function(data) {
            root.onPreviewLoaded(chatId, data);
        }, function(err) {
            root.onPreviewError(chatId);
        });
    }

    function onPreviewLoaded(chatId, data) {
        root.finishPreviewLoad(chatId);
        var raw = root.itemsOf(data, "messages");
        if (raw.length === 0) return;
        var sorted = TM.sortMessages(raw);
        root.applyPreview(chatId, TM.normalizeMessage(sorted[sorted.length - 1]));
    }

    function applyPreview(chatId, preview) {
        var out = [];
        for (var i = 0; i < root.chats.length; i++) {
            var c = root.chats[i];
            if (c && c.id === chatId) c = Object.assign({}, c, { preview: preview });
            out.push(c);
        }
        root.chats = out;
        root.refreshSnapshotPreview(chatId, preview);
    }

    function refreshSnapshotPreview(chatId, preview) {
        var snap = root.retainedPins[chatId];
        if (!snap) return;
        var kept = Object.assign({}, root.retainedPins);
        kept[chatId] = Object.assign({}, snap, { preview: preview });
        root.retainedPins = kept;
    }

    function onPreviewError(chatId) {
        root.finishPreviewLoad(chatId);
    }

    function finishPreviewLoad(chatId) {
        var loads = Object.assign({}, root.loadingPreviews);
        delete loads[chatId];
        root.loadingPreviews = loads;
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
        if (err && (err.code === "EUNTRUSTED" || err.code === "EAUTH")) {
            // Server identity unknown/changed: fall back to onboarding so
            // saving the token again re-trusts the current Beeper install.
            root.isRefreshing = false;
            root.hasToken = false;
            root.refreshFinished();
            return;
        }
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
        root.sendsInFlight++;
        root.sendStarted(chatId, localId);
        var path = "/v1/chats/" + encodeURIComponent(chatId) + "/messages";
        root.executeHttp("POST", path, { text: text }, function(data) {
            root.onSendSuccess(chatId, localId, data);
        }, function(err) {
            root.onSendFailure(chatId, localId, err);
        });
    }

    function onSendSuccess(chatId, localId, data) {
        root.sendsInFlight = Math.max(0, root.sendsInFlight - 1);
        root.sendFinished(chatId, localId);
        if (root.activeChat && root.activeChat.id === chatId) {
            root.reconcileSentMessage(localId, data ? data.id : null);
        }
        root.refreshUnread();
        root.loadMessages(chatId);
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
        root.sendsInFlight = Math.max(0, root.sendsInFlight - 1);
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

    Component {
        id: requestProcComponent
        Process {
            // Referenced by id from the collector below: the collector's
            // `parent` is not this Process, so dispatching on `parent`
            // silently misses the handlers and the inbox never loads.
            id: requestProc
            property var successHandler
            property var failureHandler
            property string payloadString: ""
            property string methodArg: ""
            property string pathArg: ""
            
            command: ["python3", Qt.resolvedUrl("beeper_bridge.py").toString().replace("file://", ""), "request", methodArg, pathArg]

            stdout: StdioCollector {
                id: stdoutCol
                waitForEnd: true
                onStreamFinished: {
                    root.handleRequestStreamFinished(requestProc, stdoutCol.text);
                }
            }
            
            Component.onCompleted: {
                running = true;
                if (payloadString) {
                    write(payloadString.length.toString() + "\n" + payloadString);
                } else {
                    write("\n");
                }
            }
        }
    }


function parseProcOutput(text) {
        if (!text) return {};
        try {
            return JSON.parse(text);
        } catch (e) {
            return { parseError: true };
        }
    }

    function notifyFailure(proc, errObj) {
        if (proc.failureHandler) proc.failureHandler(errObj);
    }

    function notifySuccess(proc, data) {
        if (proc.successHandler) proc.successHandler(data || {});
    }

    function isSuccessStatus(status) {
        return status >= 200 && status < 300;
    }

    function handleRequestStreamFinished(proc, text) {
        var p = root.parseProcOutput(text);
        if (p.parseError) root.notifyFailure(proc, { invalidBody: true });
        else if (p.error) root.notifyFailure(proc, p);
        else if (root.isSuccessStatus(p.status)) root.notifySuccess(proc, p.data);
        else root.notifyFailure(proc, { status: p.status });
        
    }

    function executeHttp(method, path, body, onSuccess, onFailure) {
        requestProcComponent.createObject(root, {
            methodArg: method,
            pathArg: path,
            payloadString: body ? JSON.stringify(body) : "",
            successHandler: onSuccess,
            failureHandler: onFailure
        });
    }

}
