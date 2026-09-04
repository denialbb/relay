import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { loadHelper } from './loadHelper.js';

const {
  filterEligibleChats,
  normalizeChat,
  normalizeMessage,
  classifyMessage,
  sortChats,
  calculateUnreadTotal,
  selectPreview,
  appendPendingMessage,
  reconcilePendingMessage,
  mapApiError,
} = loadHelper('./models/TriageModel.js');

describe('filterEligibleChats', () => {
  it('keeps unread single/group, drops read + non-single/group', () => {
    const out = filterEligibleChats([
      { type: 'single', unreadCount: 2 },
      { type: 'group', unreadCount: 1 },
      { type: 'single', unreadCount: 0 },
      { type: 'channel', unreadCount: 5 },
    ]);
    assert.deepEqual(out, [
      { type: 'single', unreadCount: 2 },
      { type: 'group', unreadCount: 1 },
    ]);
  });
});

describe('normalizeChat', () => {
  it('normalizes to TriageChat shape', () => {
    const c = normalizeChat({ id: 'a', type: 'single', unreadCount: 2, title: 'Alice' });
    assert.equal(c.id, 'a');
    assert.equal(c.type, 'single');
    assert.equal(c.unreadCount, 2);
    assert.equal(c.messagesLoaded, false);
  });
});

describe('normalizeMessage / classifyMessage', () => {
  it('TEXT + usable body -> text', () => {
    assert.equal(classifyMessage({ type: 'TEXT', text: 'hi' }), 'text');
    const m = normalizeMessage({ id: 'm1', chatId: 'c1', type: 'TEXT', text: 'hi', isUnread: true });
    assert.equal(m.kind, 'text');
    assert.equal(m.text, 'hi');
    assert.equal(m.isUnread, true);
  });

  it('non-TEXT -> unsupported', () => {
    assert.equal(classifyMessage({ type: 'IMAGE', text: 'caption' }), 'unsupported');
    const m = normalizeMessage({ id: 'm1', type: 'IMAGE', text: 'caption', isUnread: 'invalid' });
    assert.equal(m.kind, 'unsupported');
    assert.equal(m.text, null);
    assert.equal(m.isUnread, null);
  });

  it('TEXT with blank body -> unsupported', () => {
    assert.equal(classifyMessage({ type: 'TEXT', text: '   ' }), 'unsupported');
  });
});

describe('sortChats', () => {
  it('sorts by lastActivity desc', () => {
    const out = sortChats([
      { id: 'old', lastActivity: '2026-09-03T08:00:00Z' },
      { id: 'new', lastActivity: '2026-09-04T10:00:00Z' },
    ]);
    assert.equal(out[0].id, 'new');
  });
});

describe('calculateUnreadTotal', () => {
  it('sums unreadCount', () => {
    assert.equal(calculateUnreadTotal([{ unreadCount: 2 }, { unreadCount: 1 }]), 3);
  });
});

describe('selectPreview', () => {
  it('returns preview message or null', () => {
    assert.equal(selectPreview({ preview: null }), null);
  });
});

describe('appendPendingMessage / reconcilePendingMessage', () => {
  it('appends pending then reconciles to remote', () => {
    const list = appendPendingMessage([], { id: 'local-1', text: 'hi' });
    assert.equal(list.at(-1).sendState, 'pending');
    const done = reconcilePendingMessage(list, { localId: 'local-1', id: 'remote-1' });
    assert.equal(done.find((m) => m.id === 'remote-1').sendState, 'remote');
  });
});

describe('mapApiError', () => {
  it('maps 401 -> unauthorized, 429 -> rate-limited, 500 -> server-error', () => {
    assert.equal(mapApiError({ status: 401 }), 'unauthorized');
    assert.equal(mapApiError({ status: 429 }), 'rate-limited');
    assert.equal(mapApiError({ status: 500 }), 'server-error');
  });

  it('maps timeout -> beeper-unavailable, bad body -> invalid-response', () => {
    assert.equal(mapApiError({ code: 'ETIMEDOUT' }), 'beeper-unavailable');
    assert.equal(mapApiError({ invalidBody: true }), 'invalid-response');
  });
});

describe('missing TriageModel branches', () => {
  it('filterEligibleChats handles bad input', () => {
    assert.deepEqual(filterEligibleChats(null), []);
    assert.deepEqual(filterEligibleChats([null, { type: 'single', unreadCount: -1 }]), []);
  });
  
  it('classifyMessage handles bad input', () => {
    assert.equal(classifyMessage(null), 'unsupported');
    assert.equal(classifyMessage({ type: 'TEXT', text: 123 }), 'unsupported');
  });

  it('normalizeChat handles bad input', () => {
    assert.equal(normalizeChat(null), null);
    const defaults = normalizeChat({});
    assert.equal(defaults.id, '');
    assert.equal(defaults.type, 'single');
    assert.equal(defaults.unreadCount, 0);
  });

  it('sortChats handles bad input', () => {
    assert.deepEqual(sortChats(null), []);
    const sorted = sortChats([{ id: 'a' }, { id: 'b', lastActivity: '2026-09-03T08:00:00Z' }]);
    assert.equal(sorted[0].id, 'b');
  });

  it('calculateUnreadTotal handles bad input', () => {
    assert.equal(calculateUnreadTotal(null), 0);
    assert.equal(calculateUnreadTotal([{ unreadCount: 'invalid' }]), 0);
  });

  it('selectPreview handles bad input', () => {
    assert.equal(selectPreview(null), null);
  });

  it('appendPendingMessage handles bad input', () => {
    assert.deepEqual(appendPendingMessage(null, { id: 'p' }), [{ id: 'p', sendState: 'pending' }]);
    assert.deepEqual(appendPendingMessage([], null), []);
  });

  it('reconcilePendingMessage handles bad input', () => {
    assert.deepEqual(reconcilePendingMessage(null, {}), []);
    assert.deepEqual(reconcilePendingMessage([{ id: 'm' }], null), [{ id: 'm' }]);
    assert.deepEqual(reconcilePendingMessage([null], { localId: 'local' }), [null]);
  });

  it('mapApiError handles bad input', () => {
    assert.equal(mapApiError(null), 'unknown');
    assert.equal(mapApiError({ status: 200 }), 'unknown');
  });
});
