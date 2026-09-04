// BeeperApi — pure integration boundary (spec §7.1). No UI concerns.
// options is always an object so new API params don't change call sites.
// RED: all functions throw; tests define the contract.

export async function searchUnreadChats(options = {}) {
  throw new Error('not implemented: searchUnreadChats');
}

export async function listMessages(chatId, options = {}) {
  throw new Error('not implemented: listMessages');
}

export async function sendText(chatId, text, options = {}) {
  throw new Error('not implemented: sendText');
}

export async function markRead(chatId, messageId = null) {
  throw new Error('not implemented: markRead');
}
