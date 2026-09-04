// TriageModel.js — pure domain helpers, testable without Quickshell/Wayland/net.
// Contract defined in docs/relay_beeper_triage_spec.md §6, §7.3, §11, §13.

const VALID_CHAT_TYPES = new Set(["single", "group"]);

export function filterEligibleChats(chats) {
  if (!Array.isArray(chats)) return [];
  return chats.filter((c) => {
    if (!c || !VALID_CHAT_TYPES.has(c.type)) return false;
    return typeof c.unreadCount === "number" && c.unreadCount > 0;
  });
}

export function classifyMessage(message) {
  if (!message || message.type !== "TEXT") {
    return "unsupported";
  }
  if (typeof message.text !== "string" || message.text.trim().length === 0) {
    return "unsupported";
  }
  return "text";
}

function getPreview(preview) {
  if (!preview) return null;
  return normalizeMessage(preview);
}

function getChatUnread(count) {
  if (typeof count === "number") return count;
  return 0;
}

export function normalizeChat(chat) {
  if (!chat) return null;
  const c = chat;
  return {
    id: c.id ?? "",
    title: c.title ?? "",
    network: c.network ?? "",
    type: c.type ?? "single",
    avatarUrl: c.avatarUrl ?? null,
    unreadCount: getChatUnread(c.unreadCount),
    lastActivity: c.lastActivity ?? null,
    preview: getPreview(c.preview),
    messagesLoaded: Boolean(c.messagesLoaded),
    isReadOnly: Boolean(c.isReadOnly),
  };
}

function getUnreadState(isUnread) {
  if (typeof isUnread === "boolean") return isUnread;
  return null;
}

// Unsupported keeps text: null so renderers can't leak captions (§11).
function getMessageText(kind, text) {
  if (kind !== "text") return null;
  return text;
}

export function normalizeMessage(message) {
  if (!message) return null;
  const m = message;
  const kind = classifyMessage(m);
  return {
    id: m.id ?? "",
    chatId: m.chatId ?? "",
    senderId: m.senderId ?? "",
    senderName: m.senderName ?? "",
    timestamp: m.timestamp ?? null,
    isMine: Boolean(m.isMine),
    isUnread: getUnreadState(m.isUnread),
    kind,
    text: getMessageText(kind, m.text),
    sendState: m.sendState ?? "remote",
  };
}

export function sortChats(chats) {
  if (!Array.isArray(chats)) return [];
  return [...chats].sort((a, b) => {
    const timeA = a?.lastActivity ? Date.parse(a.lastActivity) : 0;
    const timeB = b?.lastActivity ? Date.parse(b.lastActivity) : 0;
    return timeB - timeA;
  });
}

export function calculateUnreadTotal(chats) {
  if (!Array.isArray(chats)) return 0;
  return chats.reduce(
    (acc, c) => acc + (typeof c?.unreadCount === "number" ? c.unreadCount : 0),
    0,
  );
}

export function selectPreview(chat) {
  if (!chat?.preview) return null;
  return normalizeMessage(chat.preview);
}

export function appendPendingMessage(messages, pending) {
  const base = Array.isArray(messages) ? [...messages] : [];
  if (!pending) return base;
  base.push({
    ...pending,
    sendState: "pending",
  });
  return base;
}

export function reconcilePendingMessage(messages, remote) {
  if (!Array.isArray(messages)) return [];
  if (!remote) return [...messages];
  return messages.map((m) => {
    if (m?.id === remote.localId) {
      return {
        ...m,
        id: remote.id ?? m.id,
        sendState: "remote",
      };
    }
    return m;
  });
}

export function mapApiError(error) {
  if (!error) return "unknown";
  if (error.invalidBody) return "invalid-response";
  if (error.code === "ETIMEDOUT") return "beeper-unavailable";
  if (error.status === 401) return "unauthorized";
  if (error.status === 429) return "rate-limited";
  if (error.status >= 500) return "server-error";
  return "unknown";
}
