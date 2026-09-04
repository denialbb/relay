# Relay (`denial.beeper-relay`)

Keyboard-first unread Beeper triage drawer for Omarchy Quickshell (`panel` plugin).

> **Who needs my attention right now, and can I handle it in one or two actions?**

Relay provides a transient, lightweight desktop surface to triage incoming direct messages and group chats from Beeper Desktop. It allows fast scanning, reading latest plain-text context, sending quick replies, explicitly clearing unread state, or launching directly into Beeper Desktop when deeper interactions are required.

---

## Status

**Milestones M1–M3 implemented:**
- **M1 Read-only triage**: Local Beeper API integration, unread chat filtering (`single` & `group`), normalized chat model, unread badge, and keyboard-driven chat list.
- **M2 Conversation view**: Thread message retrieval, text vs unsupported classification, sender bubble styling, pending/remote/failed state indicators, and "Open in Beeper ↗" fallback cards.
- **M3 Sending & read state**: In-drawer composer (`Ctrl+Enter`), optimistic sending reconciliation, explicit `markActiveChatRead()`, and exponential backoff retry.
- **Quality gates**: 39 passing unit and contract tests (`node:test`), strict McCabe complexity gate ($C \le 8$), and Omarchy plugin validation.

---

## Architecture & Dependency Rule

```text
QML (TriageDrawer / Components)
       ↓
TriageModel (QML + JS Pure Helpers)
       ↓
BeeperService (Transport, Polling, Dedup, Backoff)
       ↓
BeeperApi (REST Endpoints Boundary)
       ↓
HTTP / Local Beeper Desktop API (http://localhost:23373)
```

- **UI Never shells out or makes direct HTTP calls**: All presentation components communicate purely via properties and signals.
- **Pure domain logic in JS**: Data normalization, message classification, chat filtering, sorting, and error mapping live in standalone JS modules independently tested without Quickshell runtime.
- **Theme integration**: Semantic color roles and spacing metrics adapt dynamically to Omarchy Quattro tokens (`qs.Commons` `Color` & `Style`) with built-in fallbacks.

---

## Keyboard Navigation

Relay is built for pure keyboard control:

| Key | Context | Action |
|---|---|---|
| `j` / `Down` | Chat List | Select next chat |
| `k` / `Up` | Chat List | Select previous chat |
| `Enter` | Chat List | Open selected chat conversation |
| `Esc` | Chat List | Close drawer |
| `Esc` | Conversation | Return to chat list |
| `r` | Chat List / Conversation | Explicitly mark chat read (`markActiveChatRead`) |
| `c` | Conversation | Focus reply composer |
| `Ctrl + Enter` | Composer | Submit reply and send |
| `o` | Any | Open active chat in Beeper Desktop |

*Note: Selecting or viewing a chat never marks it read automatically. Marking read is always an explicit action (`r`).*

---

## Repository Structure

```text
├── TriageDrawer.qml          # Panel entry point: layout, slide transitions, focus, keyboard map
├── components/
│   ├── ChatList.qml          # Scrollable unread chat list
│   ├── ChatRow.qml           # Individual chat item (unread indicator, snippet, timestamps)
│   ├── ChatRowHelper.js      # Pure helper functions for ChatRow formatting
│   ├── ConversationView.qml  # Thread header, message list scroller, and composer anchor
│   ├── MessageRow.qml        # Single message item (self/other, send states: pending/remote/failed)
│   ├── Composer.qml          # Reply field with busy indicators and Ctrl+Enter submit
│   ├── UnsupportedMessage.qml# Non-text / media fallback card with "Open in Beeper" button
│   ├── KeyHints.qml          # Dynamic bottom shortcut bar
│   ├── EmptyState.qml        # "Inbox Zero" presentation
│   ├── ErrorState.qml        # Actionable error presentation with retry
│   └── ErrorStateHelper.js   # Error message mapping helper
├── services/
│   ├── BeeperApi.js          # Pure API boundary (options-object REST endpoints)
│   └── BeeperService.qml     # Transport state, 5s polling, exponential backoff (1s-30s), dedup
├── models/
│   ├── TriageModel.js        # Pure domain logic (filter, normalize, classify, sort, reconcile)
│   └── TriageModel.qml       # QML bridge binding BeeperService to presentation
├── theme/
│   ├── RelayTheme.qml        # Semantic theme color roles bound to qs.Commons Color
│   └── RelayMetrics.qml      # Spacing, radius, and animation timing bound to qs.Commons Style
├── tests/
│   ├── beeper-api.test.js    # BeeperApi contract and error mapping tests
│   ├── triage-model.test.js  # Pure domain unit and mutation branch tests
│   ├── chat-row-helper.test.js # UI formatting and initials helper tests
│   └── fixtures/             # Sample Beeper API JSON responses
├── tools/
│   └── check-complexity.mjs  # Static McCabe cyclomatic complexity gate
├── docs/
│   ├── relay_beeper_triage_spec.md # Normative specification (v0.1)
│   ├── ARCHITECTURE.md       # Detailed technical architecture & state flow
│   └── KEYMAP.md             # Complete keyboard interaction guide
├── AGENTS.md                 # Universal guidelines and constraints for AI agents
├── manifest.json             # Omarchy plugin descriptor
└── Makefile                  # Test, lint, and verification targets
```

---

## Development & Testing

Run all checks:
```bash
make check
```

Individual steps:
```bash
# Validate Omarchy plugin manifest & structure
omarchy plugin validate ./

# Run QML linter (when qmllint is available)
qmllint TriageDrawer.qml components/*.qml services/*.qml models/*.qml theme/*.qml

# Run test suite
node --test tests/

# Verify McCabe cyclomatic complexity constraints (C <= 8 / 10)
node tools/check-complexity.mjs
```

---

## Specifications

- [Normative Specification (`docs/relay_beeper_triage_spec.md`)](docs/relay_beeper_triage_spec.md)
- [Architecture & Data Flow (`docs/ARCHITECTURE.md`)](docs/ARCHITECTURE.md)
- [Keyboard Reference (`docs/KEYMAP.md`)](docs/KEYMAP.md)
- [Agent Guidelines (`AGENTS.md`)](AGENTS.md)
