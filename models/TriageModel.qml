// Stub: boundary between service data and presentation. Delegates pure logic to TriageModel.js.
import QtQuick

Item {
    property var chats: []
    property string activeChatId: ""
    property var activeMessages: []
    property int unreadTotal: 0
    property string status: "idle"
    property string error: ""
    function selectChat(chatId) {}
    function closeChat() {}
    function refresh() {}
    function submitReply(text) {}
    function markActiveChatRead() {}
    function openInBeeper(chatId) {}
}
