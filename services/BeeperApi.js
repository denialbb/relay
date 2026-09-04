// BeeperApi — pure integration boundary (spec §7.1). No UI concerns.
// options is always an object so new API params don't change call sites.

let defaultBaseUrl = 'http://127.0.0.1:22373';

export function setDefaultBaseUrl(url) {
  defaultBaseUrl = url;
}

function resolveBaseUrl(options) {
  if (options && typeof options.baseUrl === 'string') return options.baseUrl;
  return defaultBaseUrl;
}

function classifyHttpStatus(status) {
  if (status === 401) return 'unauthorized';
  if (status === 429) return 'rate-limited';
  if (status >= 500) return 'server-error';
  return 'unknown';
}

function classifyNetworkError(err) {
  const code = err?.code ?? err?.cause?.code;
  if (code === 'ECONNREFUSED' || code === 'ETIMEDOUT' || err?.name === 'TimeoutError') {
    return 'beeper-unavailable';
  }
  return 'unknown';
}

async function requestJson(url, init = {}, options = {}) {
  const timeoutMs = options.timeoutMs ?? 10000;
  let response;
  try {
    response = await fetch(url, { ...init, signal: AbortSignal.timeout(timeoutMs) });
  } catch (err) {
    throw new Error(classifyNetworkError(err));
  }

  if (!response.ok) {
    throw new Error(classifyHttpStatus(response.status));
  }

  try {
    return await response.json();
  } catch {
    throw new Error('invalid-response');
  }
}

export async function searchUnreadChats(options = {}) {
  const base = resolveBaseUrl(options);
  const url = new URL('/v1/chats/search', base);
  url.searchParams.set('unreadOnly', String(options.unreadOnly ?? true));
  url.searchParams.set('type', options.type ?? 'any');
  return requestJson(url.toString(), {}, options);
}

export async function listMessages(chatId, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/messages`, base);
  if (options.limit !== undefined) {
    url.searchParams.set('limit', String(options.limit));
  }
  if (options.cursor) {
    url.searchParams.set('cursor', options.cursor);
  }
  return requestJson(url.toString(), {}, options);
}

export async function sendText(chatId, text, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/messages`, base);
  return requestJson(url.toString(), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text }),
  }, options);
}

export async function markRead(chatId, messageId = null, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/read`, base);
  const payload = typeof messageId === 'string' ? { messageId } : {};
  return requestJson(url.toString(), {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  }, options);
}
