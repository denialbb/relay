// Layer 1 — pure unit tests (spec §17.2). No Quickshell/Wayland/net. RED: impl throws.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
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
} from '../models/TriageModel.js';

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
    const m = normalizeMessage({ id: 'm1', chatId: 'c1', type: 'TEXT', text: 'hi' });
    assert.equal(m.kind, 'text');
  });

  it('non-TEXT -> unsupported', () => {
    assert.equal(classifyMessage({ type: 'IMAGE', text: 'caption' }), 'unsupported');
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
