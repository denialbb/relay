# Relay — Technical Architecture

This document describes the runtime design, separation of concerns, data flow, and error taxonomy for the Relay Beeper triage drawer (`denial.beeper-relay`).

---

## 1. System Layers

```text
┌─────────────────────────────────────────────────────────────┐
│  Presentation Layer (QML)                                  │
│  TriageDrawer.qml, components/*.qml, theme/*.qml            │
│  - Layout, styling, animation, focus trap, and keymaps      │
│  - Never makes HTTP requests or parses Beeper JSON schemas  │
└──────────────────────────────┬──────────────────────────────┘
                               │ Declarative Bindings & Signals
┌──────────────────────────────▼──────────────────────────────┐
│  Presentation Model (models/TriageModel.qml & JS)          │
│  - Bridges raw transport to UI state                        │
│  - Pure JS helpers: filter, normalize, classify, reconcile  │
└──────────────────────────────┬──────────────────────────────┘
                               │ Method calls & State Signals
┌──────────────────────────────▼──────────────────────────────┐
│  Service / Transport Layer (services/BeeperService.qml)    │
│  - Active polling timer (5s) with exponential backoff       │
│  - Request de-duplication & in-flight tracker               │
│  - XMLHttpRequest to local Beeper bridge endpoint           │
└──────────────────────────────┬──────────────────────────────┘
                               │ Options-object API
┌──────────────────────────────▼──────────────────────────────┐
│  API Boundary (services/BeeperApi.js)                       │
│  - Pure REST adapter matching Beeper local API endpoints    │
│  - Independent unit contract tests with zero network        │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Component Directory

### Presentation Layer (`components/` & root)
- **`TriageDrawer.qml`**: Entry point loaded as an Omarchy `panel`. Owns panel slide animations, focus trapping, header badge, and keyboard triage routing.
- **`components/ChatList.qml`**: Renders sorted unread chats in a non-colliding scrollable view.
- **`components/ChatRow.qml`**: Individual chat row displaying unread indicators, formatted snippet preview, initials badge, and relative timestamps.
- **`components/ConversationView.qml`**: Displays the active thread context, message bubbles, and composer.
- **`components/MessageRow.qml`**: Renders message bubbles with distinction between incoming vs outgoing and visual states (`pending`, `remote`, `failed-retriable`, `failed-permanent`).
- **`components/Composer.qml`**: Multi-line / single-line reply input with `Ctrl+Enter` dispatch and busy state.
- **`components/UnsupportedMessage.qml`**: Graceful card fallback for images, voice notes, attachments, or rich media.
- **`components/KeyHints.qml`**: Visual shortcut hint strip adapted from `omamail` styling.
- **`components/EmptyState.qml`** & **`components/ErrorState.qml`**: Empty inbox zero and actionable error states.

### Data Model Layer (`models/`)
- **`models/TriageModel.qml`**: Exposes reactive properties (`chats`, `activeChatId`, `activeMessages`, `unreadTotal`, `status`, `error`) and methods (`selectChat`, `closeChat`, `refresh`, `submitReply`, `markActiveChatRead`, `openInBeeper`).
- **`models/TriageModel.js`**: Pure testable functions:
  - `filterEligibleChats`: Retains unread `single` and `group` chats.
  - `normalizeChat` / `normalizeMessage`: Converts Beeper schema to lightweight internal shapes.
  - `classifyMessage`: Identifies `text` vs `unsupported`.
  - `sortChats`: Orders chats by latest activity timestamp descending.
  - `appendPendingMessage` / `reconcilePendingMessage`: Handles optimistic sending states.
  - `mapApiError`: Classifies HTTP and transport failures into distinct error domains.

### Transport Layer (`services/`)
- **`services/BeeperService.qml`**:
  - Polling interval: 5 seconds when drawer is visible.
  - Backoff: Exponential backoff ($1\text{s} \to 2\text{s} \to 4\text{s} \to \dots \le 30\text{s}$) upon network/server failures.
  - Dedup: Avoids overlapping message loads or search requests.
  - Local endpoint: Default `http://localhost:23373`.

---

## 3. Theme System (`theme/`)

Relay integrates natively with the active Omarchy system theme:
- **`RelayTheme.qml`**: Maps to `qs.Commons` `Color.background`, `Color.popups.background`, `Color.foreground`, `Color.muted`, `Color.accent`, `Color.urgent` with fallback hex values.
- **`RelayMetrics.qml`**: Maps to `qs.Commons` `Style.space(n)` and `Style.cornerRadius` with fallback pixel values.

UI components consume only semantic tokens (`theme.surface`, `metrics.spacingMD`) rather than hardcoded dimensions or palette colors.
