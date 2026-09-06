.pragma library

// TriageModel.js — pure domain helpers, testable without Quickshell/Wayland/net.
// Contract defined in docs/relay_beeper_triage_spec.md §6, §7.3, §11, §13.

const VALID_CHAT_TYPES = new Set(["single", "group"]);

function isVaultChat(chat) {
  if (!chat) return false;
  if (typeof chat.title === "string" && chat.title.trim().toLowerCase() === "vault") return true;
  return chat.id === "vault" || chat.id === "!EWHKJwxKdhoNLDcMGD:beeper.com";
}

function hasUnread(c) {
  if (c.isMarkedUnread === true) return true;
  return typeof c.unreadCount === "number" && c.unreadCount > 0;
}

function isMutedOrDisabled(c) {
  return Boolean(c.isReadOnly || c.isMuted || c.isArchived || c.cannotMessage);
}

function isChatEligible(c) {
  if (!c || !VALID_CHAT_TYPES.has(c.type)) return false;
  if (isVaultChat(c)) return true;
  if (c.isLowPriority === true) return false;
  if (isMutedOrDisabled(c)) return false;
  return hasUnread(c);
}

function filterEligibleChats(chats) {
  if (!Array.isArray(chats)) return [];
  return chats.filter(isChatEligible);
}

function sortMessages(messages) {
  if (!Array.isArray(messages)) return [];
  return [...messages].sort((a, b) => {
    const timeA = a && a.timestamp ? Date.parse(a.timestamp) : 0;
    const timeB = b && b.timestamp ? Date.parse(b.timestamp) : 0;
    return timeA - timeB;
  });
}

function classifyMessage(message) {
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

function extractChatStrings(c) {
  const out = { id: "", accountID: "", title: "", network: "", type: "single" };
  for (const k of ["id", "accountID", "title", "network", "type"]) {
    if (typeof c[k] === "string") out[k] = c[k];
  }
  return out;
}

function normalizeChat(chat) {
  if (!chat) return null;
  const c = chat;
  const s = extractChatStrings(c);
  return {
    id: s.id,
    accountID: s.accountID,
    title: s.title,
    network: s.network,
    type: s.type,
    avatarUrl: c.avatarUrl || null,
    unreadCount: getChatUnread(c.unreadCount),
    lastActivity: c.lastActivity || null,
    preview: getPreview(c.preview),
    messagesLoaded: Boolean(c.messagesLoaded),
    isReadOnly: Boolean(c.isReadOnly),
    isMuted: Boolean(c.isMuted),
    isLowPriority: Boolean(c.isLowPriority),
    isPinned: Boolean(c.isPinned),
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

function isSenderUser(m) {
  if (!m) return false;
  if (m.isMine || m.isSender) return true;
  return Boolean(m.isSelf);
}

function getSenderId(m) {
  if (!m) return "";
  return m.senderId || m.senderID || "";
}

function normalizeMessage(message) {
  if (!message) return null;
  const m = message;
  const kind = classifyMessage(m);
  return {
    id: m.id ?? "",
    chatId: m.chatId ?? "",
    senderId: getSenderId(m),
    senderName: m.senderName ?? "",
    timestamp: m.timestamp ?? null,
    isMine: isSenderUser(m),
    isUnread: getUnreadState(m.isUnread),
    kind,
    text: getMessageText(kind, m.text),
    sendState: m.sendState ?? "remote",
  };
}

function pinRank(c) {
  if (c && c.isPinned) return 1;
  return 0;
}

function sortChats(chats) {
  if (!Array.isArray(chats)) return [];
  return [...chats].sort((a, b) => {
    const pinDiff = pinRank(b) - pinRank(a);
    if (pinDiff !== 0) return pinDiff;
    const timeA = a?.lastActivity ? Date.parse(a.lastActivity) : 0;
    const timeB = b?.lastActivity ? Date.parse(b.lastActivity) : 0;
    return timeB - timeA;
  });
}

function calculateUnreadTotal(chats) {
  if (!Array.isArray(chats)) return 0;
  return chats.reduce(
    (acc, c) => acc + (typeof c?.unreadCount === "number" ? c.unreadCount : 0),
    0,
  );
}

// Pin retention (pure): refresh snapshots from fresh normalized chats,
// carrying older snapshots for pinned chats that went read (unreadOnly
// search no longer returns them). Local pins always snapshot when seen.
function refreshPinSnapshots(fresh, retained, localPins) {
  const kept = Object.assign({}, retained || {});
  const list = Array.isArray(fresh) ? fresh : [];
  for (const c of list) {
    if (!c || !c.id) continue;
    if (c.isPinned || (localPins && localPins[c.id])) kept[c.id] = c;
  }
  return kept;
}

// Merge retained pinned snapshots back into the fresh list (absent =
// read, so zero unread). Sorted pinned-first via sortChats.
function withRetainedPins(fresh, retained) {
  const list = Array.isArray(fresh) ? fresh : [];
  const seen = {};
  for (const c of list) {
    if (c && c.id) seen[c.id] = true;
  }
  const merged = list.slice();
  const snaps = retained || {};
  for (const id in snaps) {
    if (seen[id]) continue;
    const snap = snaps[id];
    if (!snap) continue;
    merged.push(Object.assign({}, snap, { unreadCount: 0 }));
  }
  return sortChats(merged);
}

// Data minimization: strip preview message content before writing pins to disk
function stripPreviewsForStorage(retained) {
  if (!retained || typeof retained !== "object") return {};
  const out = {};
  for (const k of Object.keys(retained)) {
    const snap = retained[k];
    if (snap) out[k] = Object.assign({}, snap, { preview: null });
  }
  return out;
}

function selectPreview(chat) {
  if (!chat?.preview) return null;
  return normalizeMessage(chat.preview);
}

function appendPendingMessage(messages, pending) {
  const base = Array.isArray(messages) ? [...messages] : [];
  if (!pending) return base;
  base.push(Object.assign({}, pending, {
    sendState: "pending",
  }));
  return base;
}

function reconcilePendingMessage(messages, remote) {
  if (!Array.isArray(messages)) return [];
  if (!remote) return [...messages];
  return messages.map((m) => {
    if (m?.id === remote.localId) {
      return Object.assign({}, m, {
        id: remote.id ?? m.id,
        sendState: "remote",
      });
    }
    return m;
  });
}

function isLocalMessage(m) {
  return Boolean(m && typeof m.id === "string" && m.id.indexOf("local-") === 0);
}

function messageTime(m) {
  var t = m && m.timestamp ? Date.parse(m.timestamp) : NaN;
  return isNaN(t) ? 0 : t;
}

function isSameAuthorText(m, local) {
  return Boolean(m && !isLocalMessage(m) && m.isMine && m.text === local.text);
}

function isFreshEnough(m, localTime) {
  return messageTime(m) >= localTime - 300000;
}

function hasServerEcho(newMessages, local) {
  if (!Array.isArray(newMessages)) return false;
  var localTime = messageTime(local);
  for (const m of newMessages) {
    if (isSameAuthorText(m, local) && isFreshEnough(m, localTime)) return true;
  }
  return false;
}

function isKeepablePending(m, seen, chatId) {
  if (!isLocalMessage(m) || seen[m.id]) return false;
  if (chatId && m.chatId && m.chatId !== chatId) return false;
  return true;
}

// Keeps locally-sent messages across service overwrites until the server
// echo arrives (same text, own, non-local id), then drops the local copy.
// ponytail: text-match echo; same-text-twice may drop both on first echo,
// next load corrects it.
function preserveUnackedMessages(oldMessages, newMessages, chatId) {
  const base = Array.isArray(newMessages) ? [...newMessages] : [];
  if (!Array.isArray(oldMessages)) return base;
  const seen = {};
  for (const m of base) {
    if (m && m.id != null) seen[m.id] = true;
  }
  for (const m of oldMessages) {
    if (!isKeepablePending(m, seen, chatId)) continue;
    if (hasServerEcho(base, m)) continue;
    base.push(m);
    seen[m.id] = true;
  }
  return base;
}

function mapApiError(error) {
  if (!error) return "unknown";
  if (error.invalidBody) return "invalid-response";
  if (error.code === "ETIMEDOUT") return "beeper-unavailable";
  if (error.status === 401) return "unauthorized";
  if (error.status === 429) return "rate-limited";
  if (error.status >= 500) return "server-error";
  return "unknown";
}
