// TriageModel.js — pure domain helpers, testable without Quickshell/Wayland/net.
// RED: all functions throw; tests in tests/triage-model.test.js define the contract.

export function filterEligibleChats(chats) {
  throw new Error('not implemented: filterEligibleChats');
}

export function normalizeChat(chat) {
  throw new Error('not implemented: normalizeChat');
}

export function normalizeMessage(message) {
  throw new Error('not implemented: normalizeMessage');
}

export function classifyMessage(message) {
  throw new Error('not implemented: classifyMessage');
}

export function sortChats(chats) {
  throw new Error('not implemented: sortChats');
}

export function calculateUnreadTotal(chats) {
  throw new Error('not implemented: calculateUnreadTotal');
}

export function selectPreview(chat) {
  throw new Error('not implemented: selectPreview');
}

export function appendPendingMessage(messages, pending) {
  throw new Error('not implemented: appendPendingMessage');
}

export function reconcilePendingMessage(messages, remote) {
  throw new Error('not implemented: reconcilePendingMessage');
}

export function mapApiError(error) {
  throw new Error('not implemented: mapApiError');
}
