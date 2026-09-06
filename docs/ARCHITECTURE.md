# Relay — Technical Architecture

This document describes the runtime design, separation of concerns, data flow, security architecture, and error taxonomy for the Relay Beeper triage drawer (`denial.beeper-relay`) v1.0.0.

---

## 1. System Layers

```text
┌─────────────────────────────────────────────────────────────┐
│  Presentation Layer (QML)                                  │
│  BarWidget.qml, TriageDrawer.qml, components/*.qml          │
│  - 300px compact surface, slide transitions, focus trapping │
│  - Inline quick reply modal & eliding key hints footer      │
│  - Never makes HTTP requests or parses Beeper JSON schemas  │
└──────────────────────────────┬──────────────────────────────┘
                               │ Declarative Bindings & Signals
┌──────────────────────────────▼──────────────────────────────┐
│  Presentation Model (models/TriageModel.qml & JS)          │
│  - Bridges raw transport to UI state                        │
│  - Pure JS helpers: filter, normalize, classify, reconcile  │
│  - Pin retention logic & disk storage minimization          │
└──────────────────────────────┬──────────────────────────────┘
                               │ Method calls & State Signals
┌──────────────────────────────▼──────────────────────────────┐
│  Service / Transport Layer (services/BeeperService.qml)    │
│  - Active polling timer (5s) with exponential backoff       │
│  - Request de-duplication & in-flight tracker               │
│  - Credential & pin persistence with 0700/0600 permissions  │
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
- **`BarWidget.qml`**: Status bar launcher icon with unread badge and panel wrapper (`contentWidth: Style.space(400)`, `contentHeight: cappedContentHeight(Style.space(310))`).
- **`TriageDrawer.qml`**: Main drawer surface (`implicitWidth: 400`, `implicitHeight: 300`). Owns focus trapping, keyboard routing, inline quick reply modal (`i`), and centered eliding formatted text footer (`formatHints`).
- **`components/ChatList.qml`**: Scrollable unread chat list with non-colliding layout and immediate first-item selection.
- **`components/ChatRow.qml`**: Individual chat row with unread status indicator, snippet preview, initials badge, and relative timestamps.
- **`components/ConversationView.qml`**: Displays active thread context, message bubbles, and composer anchor.
- **`components/MessageRow.qml`**: Renders message bubbles (incoming vs outgoing) with visual send states (`pending`, `remote`, `failed-retriable`, `failed-permanent`).
- **`components/Composer.qml`**: Compact bubble reply input with `Enter` dispatch, `Shift+Enter` newlines, and busy spinner.
- **`components/OnboardingView.qml`**: First-run local API token onboarding flow with instructions and secure token submission.
- **`components/UnsupportedMessage.qml`**: Graceful card fallback for images, attachments, voice notes, or rich media with "Open in Beeper ↗" launcher.
- **`components/EmptyState.qml`** & **`components/ErrorState.qml`**: Inbox zero and actionable error states.
- *(Note: `KeyHints.qml` was retired in favor of the clean, centered eliding `formatHints` footer in `TriageDrawer.qml`).*

### Data Model Layer (`models/`)
- **`models/TriageModel.qml`**: Reactive bridge exposing properties (`chats`, `activeChatId`, `activeMessages`, `unreadTotal`, `status`, `error`) and triage methods (`selectChat`, `closeChat`, `refresh`, `quickReply`, `submitReply`, `togglePin`, `markActiveChatRead`, `openInBeeper`).
- **`models/TriageModel.js`**: Pure testable domain logic:
  - `filterEligibleChats`: Retains unread `single` and `group` chats, excludes low-priority and muted/archived chats.
  - `normalizeChat` / `normalizeMessage`: Normalizes Beeper schemas to internal representations.
  - `classifyMessage`: Identifies `text` vs `unsupported`.
  - `sortChats`: Orders pinned chats first, then sorts by latest activity timestamp descending.
  - `appendPendingMessage` / `reconcilePendingMessage` / `preserveUnackedMessages`: Optimistic send pipeline.
  - `refreshPinSnapshots` / `withRetainedPins` / `stripPreviewsForStorage`: Retains pins across clearance while purging message text from disk.
  - `mapApiError`: Maps HTTP status and network faults into distinct error categories.

### Transport Layer (`services/`)
- **`services/BeeperService.qml`**:
  - Polling interval: 5 seconds when drawer is visible.
  - Backoff: Exponential backoff ($1\text{s} \to 2\text{s} \to 4\text{s} \to \dots \le 30\text{s}$) upon network or server failures.
  - Request de-duplication: Prevents overlapping message loads or sync calls.
  - Local endpoint: Defaults to `http://localhost:23373`.
  - Persistent storage: Manages `token` and `pins.json` with strict POSIX permissions.

---

## 3. Storage & Security Architecture

Relay is designed with strict local security and data minimization principles:

1. **POSIX Permissions**:
   - Configuration directory (`~/.config/beeper-relay/`) is created with mode `0700` (`mkdir -p -m 700`).
   - Token file (`~/.config/beeper-relay/token`) is written with mode `0600` via `umask 077`.
   - Pins file (`~/.config/beeper-relay/pins.json`) is restricted to the owning user.
2. **Data Minimization**:
   - `stripPreviewsForStorage`: Strips all message `preview` content from retained chat snapshots before serializing `pins.json` to disk. No message bodies or snippet text linger on disk.
3. **Redaction & Privacy**:
   - Bearer authentication tokens and HTTP request/response bodies are never logged to console or telemetry.

---

## 4. Theme System (`theme/`)

Relay integrates natively with the active Omarchy system theme:
- **`RelayTheme.qml`**: Maps to `qs.Commons` `Color.background`, `Color.popups.background`, `Color.foreground`, `Color.muted`, `Color.accent`, `Color.urgent` with fallback values.
- **`RelayMetrics.qml`**: Maps to `qs.Commons` `Style.space(n)` and `Style.cornerRadius` with fallback pixel values.

All UI components consume semantic tokens (`theme.surfaceRaised`, `metrics.spacingMD`) rather than hardcoded colors or pixel values.

---

## 5. Quality Gates & Testing

- **Contract & Unit Tests**: 71 tests across 18 suites (`node:test`) verifying mock API contracts, model normalization, optimistic sending reconciliation, pin retention, error mapping, key hints wrapping, and geometry crop calculations.
- **McCabe Cyclomatic Complexity**: Enforced via `tools/check-complexity.mjs`:
  - Domain / Model JS: $C \le 8$
  - API Adapter JS: $C \le 8$
  - Service QML: $C \le 10$
  - QML event handlers: $C \le 5$
  - UI helpers: $C \le 6$
- **Omarchy Plugin Validation**: Verified via `omarchy plugin validate ./`.

