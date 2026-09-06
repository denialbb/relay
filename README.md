# Relay (`denial.beeper-relay`)

Keyboard-first unread Beeper triage drawer for Omarchy Quickshell (`panel` plugin).

> **Who needs my attention right now, and can I handle it in one or two actions?**

Relay provides a transient, lightweight desktop surface to triage incoming direct messages and group chats from Beeper Desktop. It allows fast scanning, reading latest plain-text context, sending quick replies, explicitly clearing unread state, or launching directly into Beeper Desktop when deeper interactions are required.

---

## Status & Release (v1.0.0)

**v1.0.0 official release ready:**
- **Compact Surface**: Halved drawer height to a sleek 300px compact surface (`BarWidget.qml` cappedContentHeight: 310px; `TriageDrawer.qml` implicitHeight: 300px).
- **Fast Keyboard Triage**: Full keyboard navigation (`j`/`k`, `Enter`/`o`, `r`, `b`, `p`, `h`, `?`, `Esc`/`q`) with instant first-item selection on load.
- **Inline Quick Reply**: Direct inline reply modal (`i`) from the chat list with auto-expanding multiline input up to 100px.
- **Optimistic Composer**: Compact message bubbles matching Omarchy tokens; `Enter` sends with instant pending spinner, `Shift+Enter` inserts newlines.
- **Pin Retention & Privacy**: Pinned chats sort first and survive inbox zero clearance; message text is stripped from disk snapshots.
- **Security & Onboarding**: First-run `OnboardingView.qml` prompts for local token when missing. Storage is hardened with directory permissions `0700` and files `0600` (`umask 077`).
- **Quality Gates**: 65 unit and contract tests passing across 17 suites (`node:test`) with full mock API contracts, pin retention, error mapping, and geometry crop tests; strict McCabe cyclomatic complexity gate ($C \le 8$).

---

## Architecture & Dependency Rule

```text
QML (BarWidget / TriageDrawer / Components)
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
- **Clean Component Architecture**: `KeyHints.qml` is retired in favor of a clean, eliding formatted text footer (`formatHints`). First-run setup is handled cleanly via `OnboardingView.qml`.

---

## Keyboard Navigation

Relay is built for pure keyboard control:

| Key | Context | Action |
|---|---|---|
| `j` / `Down` | Chat List / Conversation | Select next chat / scroll message history down |
| `k` / `Up` | Chat List / Conversation | Select previous chat / scroll message history up |
| `Enter` / `o` | Chat List | Open selected chat conversation (defaults to first chat on load) |
| `i` | Chat List | Open quick reply inline modal (auto-expanding multiline input up to 100px) |
| `i` / `c` | Conversation | Focus reply composer |
| `p` | Chat List / Conversation | Toggle pin on active chat (pinned chats sort first, retained across clearance) |
| `h` (or `Ctrl+p`) | Chat List / Conversation | Toggle hide pinned chats (`Relay · pins hidden`) |
| `r` | Chat List / Conversation | Explicitly mark active chat as read (`Ctrl+r` force-refreshes inbox) |
| `b` | Chat List / Conversation | Launch directly into Beeper Desktop (`beeper://chat/<chatId>`) |
| `?` | Any | Toggle centered key hints bar between compact and full shortcut view |
| `Esc` (or `q`) | Any | Close drawer, cancel quick reply, or return from conversation to chat list |
| `Enter` | Composer / Quick Reply | Send message (immediate optimistic pending state with spinner) |
| `Shift+Enter` | Composer / Quick Reply | Insert newline |

*Note: Selecting or viewing a chat never marks it read automatically. Marking read is always an explicit action (`r`).*

---

## Repository Structure

```text
├── BarWidget.qml             # Status bar launcher button and panel popup wrapper (cappedContentHeight: 310px)
├── TriageDrawer.qml          # Panel entry point: layout, focus trap, inline quick reply, eliding footer
├── components/
│   ├── ChatList.qml          # Scrollable unread chat list
│   ├── ChatRow.qml           # Individual chat item (unread indicator, snippet, timestamps)
│   ├── ChatRowHelper.js      # Pure helper functions for ChatRow formatting
│   ├── ConversationView.qml  # Thread header, message list scroller, and composer anchor
│   ├── MessageRow.qml        # Single message item (self/other, send states: pending/remote/failed)
│   ├── Composer.qml          # Reply field with busy indicators and Enter send / Shift+Enter newline
│   ├── UnsupportedMessage.qml# Non-text / media fallback card with "Open in Beeper" button
│   ├── OnboardingView.qml    # First-run local API token onboarding flow
│   ├── EmptyState.qml        # "Inbox Zero" presentation
│   ├── ErrorState.qml        # Actionable error presentation with retry
│   └── ErrorStateHelper.js   # Error message mapping helper
├── services/
│   ├── BeeperApi.js          # Pure API boundary (options-object REST endpoints)
│   └── BeeperService.qml     # Transport state, 5s polling, exponential backoff (1s-30s), dedup, token/pin storage
├── models/
│   ├── TriageModel.js        # Pure domain logic (filter, normalize, classify, sort, reconcile, pin retention)
│   └── TriageModel.qml       # QML bridge binding BeeperService to presentation
├── theme/
│   ├── RelayTheme.qml        # Semantic theme color roles bound to qs.Commons Color
│   └── RelayMetrics.qml      # Spacing, radius, and animation timing bound to qs.Commons Style
├── tests/
│   ├── beeper-api.test.js    # BeeperApi contract and error mapping tests
│   ├── triage-model.test.js  # Pure domain unit, pin retention, and mutation branch tests
│   ├── chat-row-helper.test.js # UI formatting and initials helper tests
│   ├── drive-geometry.test.mjs # Panel crop geometry calculation tests
│   ├── message-classification.test.js # Message type classifier tests
│   └── fixtures/             # Sample Beeper API JSON responses
├── tools/
│   ├── check-complexity.mjs  # Static McCabe cyclomatic complexity gate
│   ├── drive-geometry.mjs    # Monitor geometry calculation utility
│   └── drive-relay.mjs       # Headless test driving helper
├── docs/
│   ├── relay_beeper_triage_spec.md # Normative specification (v0.1)
│   ├── ARCHITECTURE.md       # Detailed technical architecture & state flow
│   ├── KEYMAP.md             # Complete keyboard interaction guide
│   ├── SECURITY_AUDIT.md     # Security audit & permissions hardening report
│   └── human_plugin_review.md# UX and design critique
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
qmllint BarWidget.qml TriageDrawer.qml components/*.qml services/*.qml models/*.qml theme/*.qml

# Run test suite (65 tests across 17 suites)
node --test tests/

# Verify McCabe cyclomatic complexity constraints (C <= 8 / 10)
node tools/check-complexity.mjs
```

---

## Specifications & Documentation

- [Normative Specification (`docs/relay_beeper_triage_spec.md`)](docs/relay_beeper_triage_spec.md)
- [Architecture & Data Flow (`docs/ARCHITECTURE.md`)](docs/ARCHITECTURE.md)
- [Keyboard Reference (`docs/KEYMAP.md`)](docs/KEYMAP.md)
- [Security Audit & Hardening (`docs/SECURITY_AUDIT.md`)](docs/SECURITY_AUDIT.md)
- [Agent Guidelines (`AGENTS.md`)](AGENTS.md)
