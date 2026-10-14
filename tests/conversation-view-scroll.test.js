// Regression guard for ConversationView scroll-to-bottom and dead code invariants.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const convViewSource = readFileSync(
  new URL("../components/ConversationView.qml", import.meta.url),
  "utf8",
);

const drawerSource = readFileSync(
  new URL("../TriageDrawer.qml", import.meta.url),
  "utf8",
);

test("ConversationView tracks atBottom state", () => {
  assert.match(convViewSource, /property\s+bool\s+atBottom:\s*true/);
});

test("ConversationView scrolls to bottom on chatChanged, messagesChanged, and visibleChanged", () => {
  assert.match(convViewSource, /onChatChanged:\s*\{[\s\S]*?atBottom\s*=\s*true[\s\S]*?scrollToBottom/);
  assert.match(convViewSource, /onMessagesChanged:\s*\{[\s\S]*?atBottom[\s\S]*?scrollToBottom/);
  assert.match(convViewSource, /onVisibleChanged:\s*\{[\s\S]*?atBottom\s*=\s*true[\s\S]*?scrollToBottom/);
});

test("ListView reacts to contentHeightChanged and countChanged to stick to bottom", () => {
  assert.match(convViewSource, /onContentHeightChanged:\s*\{[\s\S]*?atBottom[\s\S]*?scrollToBottom/);
  assert.match(convViewSource, /onCountChanged:\s*\{[\s\S]*?atBottom[\s\S]*?scrollToBottom/);
});

test("ListView adapts height changes maintaining bottom position", () => {
  assert.match(convViewSource, /onHeightChanged:\s*\{[\s\S]*?atBottom[\s\S]*?scrollToBottom[\s\S]*?clampScroll/);
});

test("scrollUp detaches atBottom while scrolling to bottom restores it", () => {
  assert.match(convViewSource, /function\s+scrollUp\(\)\s*\{[\s\S]*?atBottom\s*=\s*false/);
  assert.match(convViewSource, /function\s+scrollToBottom\(\)\s*\{[\s\S]*?positionViewAtEnd/);
  assert.match(convViewSource, /function\s+scrollBy\(delta\)\s*\{[\s\S]*?atBottom\s*=\s*true/);
});

test("dead signals and properties are removed from ConversationView", () => {
  assert.doesNotMatch(convViewSource, /signal\s+requestBack/);
  assert.doesNotMatch(convViewSource, /signal\s+requestMarkRead/);
  assert.doesNotMatch(convViewSource, /property\s+.*chatTitle/);
  assert.doesNotMatch(convViewSource, /property\s+.*canMarkRead/);
});

test("dead signal handlers are removed from conversationView in TriageDrawer", () => {
  assert.doesNotMatch(drawerSource, /onRequestMarkRead:/);
  assert.doesNotMatch(drawerSource, /onRequestBack:/);
});
