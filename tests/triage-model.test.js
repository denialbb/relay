import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { loadHelper } from "./loadHelper.js";

const {
  filterEligibleChats,
  normalizeChat,
  normalizeMessage,
  classifyMessage,
  sortChats,
  sortMessages,
  calculateUnreadTotal,
  selectPreview,
  appendPendingMessage,
  reconcilePendingMessage,
  preserveUnackedMessages,
  isLocalMessage,
  mapApiError,
  refreshPinSnapshots,
  withRetainedPins,
  stripPreviewsForStorage,
} = loadHelper("./models/TriageModel.js");

describe("filterEligibleChats", () => {
  it("keeps unread single/group, drops read + non-single/group", () => {
    const out = filterEligibleChats([
      { type: "single", unreadCount: 2 },
      { type: "group", unreadCount: 1 },
      { type: "single", unreadCount: 0 },
      { type: "channel", unreadCount: 5 },
    ]);
    assert.deepEqual(out, [
      { type: "single", unreadCount: 2 },
      { type: "group", unreadCount: 1 },
    ]);
  });

  it("drops read-only channels even if unreadCount > 0", () => {
    const out = filterEligibleChats([
      { type: "single", unreadCount: 2, isReadOnly: false },
      {
        type: "group",
        unreadCount: 9,
        isReadOnly: true,
        title: "Tabz - Live News",
      },
      { type: "group", unreadCount: 16, isReadOnly: true, title: "RaiNews" },
    ]);
    assert.deepEqual(out, [
      { type: "single", unreadCount: 2, isReadOnly: false },
    ]);
  });

  it("always includes VAULT chat even if unreadCount is 0", () => {
    const out = filterEligibleChats([
      { id: "vault-1", type: "single", unreadCount: 0, title: "VAULT" },
      {
        id: "!EWHKJwxKdhoNLDcMGD:beeper.com",
        type: "single",
        unreadCount: 0,
        title: "Personal Notes",
      },
      { id: "regular", type: "single", unreadCount: 0, title: "Regular" },
    ]);
    assert.deepEqual(out, [
      { id: "vault-1", type: "single", unreadCount: 0, title: "VAULT" },
      {
        id: "!EWHKJwxKdhoNLDcMGD:beeper.com",
        type: "single",
        unreadCount: 0,
        title: "Personal Notes",
      },
    ]);
  });

  it("includes chats with isMarkedUnread: true even if unreadCount is 0", () => {
    const out = filterEligibleChats([
      { type: "single", unreadCount: 0, isMarkedUnread: true },
    ]);
    assert.equal(out.length, 1);
  });

  it("drops muted, archived, or cannotMessage chats", () => {
    const out = filterEligibleChats([
      {
        id: "c1",
        type: "single",
        unreadCount: 2,
        isMuted: true,
        title: "Twitch monitor",
      },
      { id: "c2", type: "group", unreadCount: 3, isArchived: true },
      { id: "c3", type: "group", unreadCount: 4, cannotMessage: true },
      { id: "c4", type: "single", unreadCount: 1, isMuted: false },
    ]);
    assert.deepEqual(
      out.map((c) => c.id),
      ["c4"],
    );
  });
  it("drops low-priority chats even when unread", () => {
    const out = filterEligibleChats([
      { id: "a", type: "group", unreadCount: 3, isLowPriority: true },
      { id: "b", type: "group", unreadCount: 3 },
    ]);
    assert.deepEqual(
      out.map((c) => c.id),
      ["b"],
    );
  });
});

describe("sortMessages", () => {
  it("sorts messages chronologically (oldest first, newest last)", () => {
    const out = sortMessages([
      { id: "m2", timestamp: "2026-09-04T12:00:00Z" },
      { id: "m1", timestamp: "2026-09-03T12:00:00Z" },
      { id: "m3", timestamp: "2026-09-05T12:00:00Z" },
    ]);
    assert.deepEqual(
      out.map((m) => m.id),
      ["m1", "m2", "m3"],
    );
  });

  it("handles bad input safely", () => {
    assert.deepEqual(sortMessages(null), []);
    assert.deepEqual(sortMessages([]), []);
  });
});

describe("normalizeChat", () => {
  it("normalizes to TriageChat shape", () => {
    const c = normalizeChat({
      id: "a",
      accountID: "whatsapp",
      type: "single",
      unreadCount: 2,
      title: "Alice",
    });
    assert.equal(c.id, "a");
    assert.equal(c.accountID, "whatsapp");
    assert.equal(c.type, "single");
    assert.equal(c.unreadCount, 2);
    assert.equal(c.messagesLoaded, false);
  });

  it("passes through isLowPriority/isPinned flags", () => {
    const c = normalizeChat({
      id: "a",
      type: "group",
      isLowPriority: true,
      isPinned: true,
    });
    assert.equal(c.isLowPriority, true);
    assert.equal(c.isPinned, true);
    const d = normalizeChat({ id: "b", type: "group" });
    assert.equal(d.isLowPriority, false);
    assert.equal(d.isPinned, false);
  });
});

describe("normalizeMessage / classifyMessage", () => {
  it("TEXT + usable body -> text", () => {
    assert.equal(classifyMessage({ type: "TEXT", text: "hi" }), "text");
    const m = normalizeMessage({
      id: "m1",
      chatId: "c1",
      type: "TEXT",
      text: "hi",
      isUnread: true,
    });
    assert.equal(m.kind, "text");
    assert.equal(m.text, "hi");
    assert.equal(m.isUnread, true);
  });

  it("normalizes isMine from isSender: true or isSelf: true", () => {
    const m1 = normalizeMessage({
      id: "m1",
      type: "TEXT",
      text: "hi",
      isSender: true,
    });
    assert.equal(m1.isMine, true);
    const m2 = normalizeMessage({
      id: "m2",
      type: "TEXT",
      text: "hello",
      isSelf: true,
    });
    assert.equal(m2.isMine, true);
    const m3 = normalizeMessage({
      id: "m3",
      type: "TEXT",
      text: "hey",
      isSender: false,
    });
    assert.equal(m3.isMine, false);
  });

  it("non-TEXT -> unsupported", () => {
    assert.equal(
      classifyMessage({ type: "IMAGE", text: "caption" }),
      "unsupported",
    );
    const m = normalizeMessage({
      id: "m1",
      type: "IMAGE",
      text: "caption",
      isUnread: "invalid",
    });
    assert.equal(m.kind, "unsupported");
    assert.equal(m.text, null);
    assert.equal(m.isUnread, null);
  });

  it("TEXT with blank body -> unsupported", () => {
    assert.equal(classifyMessage({ type: "TEXT", text: "   " }), "unsupported");
  });
});

describe("sortChats", () => {
  it("sorts by lastActivity desc", () => {
    const out = sortChats([
      { id: "old", lastActivity: "2026-09-03T08:00:00Z" },
      { id: "new", lastActivity: "2026-09-04T10:00:00Z" },
    ]);
    assert.equal(out[0].id, "new");
  });

  it("sorts pinned chats first regardless of activity", () => {
    const out = sortChats([
      { id: "new", lastActivity: "2026-09-04T10:00:00Z" },
      {
        id: "pinned-old",
        lastActivity: "2026-09-01T08:00:00Z",
        isPinned: true,
      },
    ]);
    assert.equal(out[0].id, "pinned-old");
  });
});

describe("pin retention", () => {
  it("refreshPinSnapshots keeps pinned snapshots and carries old ones", () => {
    const kept = refreshPinSnapshots(
      [{ id: "a", isPinned: true }, { id: "b" }],
      { c: { id: "c" } },
      { b: true },
    );
    assert.deepEqual(Object.keys(kept).sort(), ["a", "b", "c"]);
  });

  it("refreshPinSnapshots preserves existing preview when incoming has none", () => {
    const kept = refreshPinSnapshots(
      [{ id: "a", isPinned: true, preview: null }],
      { a: { id: "a", isPinned: true, preview: { text: "saved preview" } } },
      null,
    );
    assert.equal(kept.a.preview?.text, "saved preview");
  });

  it("withRetainedPins re-adds absent pins zeroed and sorted first", () => {
    const out = withRetainedPins(
      [{ id: "fresh", lastActivity: "2026-09-04T10:00:00Z" }],
      {
        old: {
          id: "old",
          isPinned: true,
          unreadCount: 3,
          lastActivity: "2026-09-01T08:00:00Z",
        },
      },
    );
    assert.equal(out[0].id, "old");
    assert.equal(out[0].unreadCount, 0);
    assert.deepEqual(withRetainedPins(null, null), []);
  });
});

describe("stripPreviewsForStorage", () => {
  it("strips preview from retained chat snapshots for storage minimization", () => {
    const input = {
      c1: { id: "c1", title: "Secret", preview: { text: "private message" } },
      c2: { id: "c2", title: "Public", preview: null },
    };
    const out = stripPreviewsForStorage(input);
    assert.deepEqual(out.c1, { id: "c1", title: "Secret", preview: null });
    assert.deepEqual(out.c2, { id: "c2", title: "Public", preview: null });
  });

  it("handles empty or invalid inputs safely", () => {
    assert.deepEqual(stripPreviewsForStorage(null), {});
    assert.deepEqual(stripPreviewsForStorage(undefined), {});
    assert.deepEqual(stripPreviewsForStorage("bad"), {});
  });
});

describe("calculateUnreadTotal", () => {
  it("sums unreadCount", () => {
    assert.equal(
      calculateUnreadTotal([{ unreadCount: 2 }, { unreadCount: 1 }]),
      3,
    );
  });
});

describe("selectPreview", () => {
  it("returns preview message or null", () => {
    assert.equal(selectPreview({ preview: null }), null);
  });
});

describe("appendPendingMessage / reconcilePendingMessage", () => {
  it("appends pending then reconciles to remote", () => {
    const list = appendPendingMessage([], { id: "local-1", text: "hi" });
    assert.equal(list.at(-1).sendState, "pending");
    const done = reconcilePendingMessage(list, {
      localId: "local-1",
      id: "remote-1",
    });
    assert.equal(done.find((m) => m.id === "remote-1").sendState, "remote");
  });
});

describe("preserveUnackedMessages", () => {
  it("keeps pending across service overwrite, drops it on server echo", () => {
    const pending = {
      id: "local-1",
      chatId: "c1",
      sendState: "pending",
      isMine: true,
      text: "hi",
    };
    const kept = preserveUnackedMessages([pending], [{ id: "m1" }], "c1");
    assert.deepEqual(kept, [{ id: "m1" }, pending]);
    const echoed = preserveUnackedMessages(
      kept,
      [{ id: "m1" }, { id: "m2", isMine: true, text: "hi" }],
      "c1",
    );
    assert.deepEqual(echoed, [
      { id: "m1" },
      { id: "m2", isMine: true, text: "hi" },
    ]);
  });

  it("keeps sent local without echo (server lag), skips other chats", () => {
    const sent = {
      id: "local-2",
      chatId: "c1",
      sendState: "remote",
      isMine: true,
      text: "yo",
    };
    assert.deepEqual(preserveUnackedMessages([sent], [{ id: "m1" }], "c1"), [
      { id: "m1" },
      sent,
    ]);
    const other = { id: "local-9", chatId: "c2", sendState: "pending" };
    assert.deepEqual(preserveUnackedMessages([other], [], "c1"), []);
  });

  it("handles bad input", () => {
    assert.deepEqual(preserveUnackedMessages(null, null), []);
    assert.deepEqual(preserveUnackedMessages([{ id: "m" }], null), []);
    assert.equal(isLocalMessage({ id: "local-1" }), true);
    assert.equal(isLocalMessage({ id: "m1" }), false);
    assert.equal(isLocalMessage(null), false);
  });

  it("ignores stale same-text messages (not echoes)", () => {
    const pending = {
      id: "local-3",
      chatId: "c1",
      sendState: "pending",
      isMine: true,
      text: "again",
      timestamp: "2026-09-06T01:00:00.000Z",
    };
    const stale = {
      id: "m-old",
      isMine: true,
      text: "again",
      timestamp: "2026-09-05T23:00:00.000Z",
    };
    assert.deepEqual(preserveUnackedMessages([pending], [stale], "c1"), [
      stale,
      pending,
    ]);
  });
});

describe("mapApiError", () => {
  it("maps 401 -> unauthorized, 429 -> rate-limited, 500 -> server-error", () => {
    assert.equal(mapApiError({ status: 401 }), "unauthorized");
    assert.equal(mapApiError({ status: 429 }), "rate-limited");
    assert.equal(mapApiError({ status: 500 }), "server-error");
  });

  it("maps timeout -> beeper-unavailable, bad body -> invalid-response", () => {
    assert.equal(mapApiError({ code: "ETIMEDOUT" }), "beeper-unavailable");
    assert.equal(mapApiError({ invalidBody: true }), "invalid-response");
  });
});

describe("missing TriageModel branches", () => {
  it("filterEligibleChats handles bad input", () => {
    assert.deepEqual(filterEligibleChats(null), []);
    assert.deepEqual(
      filterEligibleChats([null, { type: "single", unreadCount: -1 }]),
      [],
    );
  });

  it("classifyMessage handles bad input", () => {
    assert.equal(classifyMessage(null), "unsupported");
    assert.equal(classifyMessage({ type: "TEXT", text: 123 }), "unsupported");
  });

  it("normalizeChat handles bad input", () => {
    assert.equal(normalizeChat(null), null);
    const defaults = normalizeChat({});
    assert.equal(defaults.id, "");
    assert.equal(defaults.type, "single");
    assert.equal(defaults.unreadCount, 0);
  });

  it("sortChats handles bad input", () => {
    assert.deepEqual(sortChats(null), []);
    const sorted = sortChats([
      { id: "a" },
      { id: "b", lastActivity: "2026-09-03T08:00:00Z" },
    ]);
    assert.equal(sorted[0].id, "b");
  });

  it("calculateUnreadTotal handles bad input", () => {
    assert.equal(calculateUnreadTotal(null), 0);
    assert.equal(calculateUnreadTotal([{ unreadCount: "invalid" }]), 0);
  });

  it("selectPreview handles bad input", () => {
    assert.equal(selectPreview(null), null);
  });

  it("appendPendingMessage handles bad input", () => {
    assert.deepEqual(appendPendingMessage(null, { id: "p" }), [
      { id: "p", sendState: "pending" },
    ]);
    assert.deepEqual(appendPendingMessage([], null), []);
  });

  it("reconcilePendingMessage handles bad input", () => {
    assert.deepEqual(reconcilePendingMessage(null, {}), []);
    assert.deepEqual(reconcilePendingMessage([{ id: "m" }], null), [
      { id: "m" },
    ]);
    assert.deepEqual(reconcilePendingMessage([null], { localId: "local" }), [
      null,
    ]);
  });

  it("mapApiError handles bad input", () => {
    assert.equal(mapApiError(null), "unknown");
    assert.equal(mapApiError({ status: 200 }), "unknown");
  });
});
