// Stub: transport state, retry/backoff, dedup, normalization. No visual state.
import QtQuick

Item {
    property string status: "idle"
    property var chats: []
    property var activeChat
    property string lastRefreshAt: ""
    property string lastError: ""
    property bool pollingActive: false
    signal stateChanged()
    signal refreshStarted()
    signal refreshFinished()
    signal sendStarted(string chatId, string localMessageId)
    signal sendFinished(string chatId, string localMessageId)
    signal errorChanged()
    function initialize() {}
    function refreshUnread() {}
    function loadMessages(chatId) {}
    function sendText(chatId, text) {}
    function markRead(chatId, messageId) {}
    function retry() {}
    function stopPolling() {}
}
