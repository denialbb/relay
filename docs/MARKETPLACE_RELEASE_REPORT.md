# Omarchy Plugin Marketplace Release Report: Relay

**Plugin ID:** `denial.beeper-relay`  
**Display Name:** Relay  
**Version:** `v1.1.0`  
**Author:** denial  
**License:** MIT  
**Category:** Communication  
**Repository:** [https://github.com/denialbb/relay](https://github.com/denialbb/relay)  
**Target Runtime:** Omarchy Quattro / Quickshell $\ge$ v0.3.0 / Wayland  

---

## 1. Executive Summary & Purpose

**Relay** is a keyboard-driven triage drawer for unread Beeper chats, built natively for the Omarchy Quattro shell using Quickshell and Qt Quick.

Relay is deliberately **not** a Beeper client replacement:
- It exclusively targets unread direct messages and active group chats to achieve inbox zero.
- It provides rapid inline keyboard triage (`j`/`k` navigation, `i` inline quick reply, `r` mark read, `p` pin retention, `b` jump to Beeper Desktop).
- It consumes the local Beeper Desktop HTTP API directly without Electron overhead, CLI subshells, or background telemetry.

---

## 2. Release Highlights (v1.1.0)

| Feature | Description |
| :--- | :--- |
| **Adaptive Drawer Layout** | Base height of 400px; interactive `Ctrl+J` / `Ctrl+K` dynamically scales drawer height between 220px and 700px with smooth cubic animation and bounds-safe scroll clamping. |
| **Unified Rounded Composer** | Unified [`components/Composer.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/components/Composer.qml) for both conversation view and inline quick reply modal (`i`). Features vertically centered input, rounded metrics, auto-expansion up to 100px, `Enter` to send, and `Shift+Enter` for newlines. |
| **Zero-Flicker Optimistic Triage** | Instantaneous local state updates when marking chats read (`r`). Eliminates redundant network refetches, preserves pinned chat snapshot previews across synchronization cycles, and prevents delegate re-instantiation thrashing. |
| **Clean Snippet Formatting** | Chat list snippets prefix user-sent messages with `You: ` and cleanly truncate to first-line plain text with HTML stripped. |
| **Pin Retention & Visibility** | Pinned chats (`p`) persist across read triage and inbox zero states. Pinned items can be hidden/shown via `h` (`Relay · pins hidden`). |
| **Smart Key Hints Footer** | Centered keyboard hints bar (`?`) formats non-breaking shortcut pairs and wraps cleanly across multiple lines without trailing separators. |
| **First-Run Onboarding** | Native [`components/OnboardingView.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/components/OnboardingView.qml) detects missing tokens, guides user through local Beeper Desktop token extraction, and persists credentials securely. |

---

## 3. Technical Architecture & Invariants

Relay enforces a strict unidirectional dependency hierarchy:

$$\text{QML UI} \longrightarrow \text{TriageModel} \longrightarrow \text{BeeperService} \longrightarrow \text{BeeperApi} \longrightarrow \text{Beeper Desktop HTTP}$$

1. **Pure Integration Boundary ([`services/BeeperApi.js`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/services/BeeperApi.js))**:
   - Single boundary for all HTTP request constructions, options-object argument passing, and response shape unwrapping.
   - Normalizes Beeper Desktop API variations (`items`, object keys, arrays).
2. **Deterministic Domain Logic ([`models/TriageModel.js`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/models/TriageModel.js))**:
   - 100% pure JavaScript, zero Quickshell/Wayland/network imports.
   - Message classification (`TEXT` vs `unsupported`), chat eligibility filtering, optimistic message reconciliation, and pin snapshot retention.
3. **Reactive State Bridge ([`services/BeeperService.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/services/BeeperService.qml))**:
   - Manages local polling timer (15s), exponential backoff retry logic, local token loading, and snapshot persistence.
   - Does not contain visual or layout state.
4. **Declarative Presentation ([`TriageDrawer.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/TriageDrawer.qml))**:
   - Consumes semantic tokens from [`theme/RelayTheme.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/theme/RelayTheme.qml) and [`theme/RelayMetrics.qml`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/theme/RelayMetrics.qml).
   - No raw color palettes or hardcoded pixel metrics in component views.

---

## 4. Quality Gates & Test Metrics

Continuous integration and pre-commit checks require zero external daemons, Wayland compositors, or network access:

```bash
make check
```

### Test Suite Summary (`node:test`)
- **72 unit and contract tests** across **18 suites** passing with **100% pass rate** ($\approx 210\text{ ms}$ execution duration).
- Test suites cover:
  - Beeper API contracts (search unread, list messages, send text, mark read, authorization headers, timeout/error mapping).
  - Triage model chat eligibility, message normalization, and chronological sorting.
  - Pinned chat retention, snapshot merging, and preview preservation.
  - Optimistic message sending and reconciliation.
  - Snippet formatting, HTML tag stripping, and initial letter extraction.
  - Error code humanization and recovery dispatching.
  - Key hint formatting, non-breaking spacing, and trailing punctuation suppression.
  - Multi-monitor crop geometry calculations.

### McCabe Cyclomatic Complexity Gate ([`tools/check-complexity.mjs`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/tools/check-complexity.mjs))
Enforces structural readability across all source files:
- **Domain & Model JS**: $C \le 8$
- **API Adapter JS**: $C \le 8$
- **Service QML**: $C \le 5$ (functions & event handlers)
- **UI Components & Helpers**: $C \le 6$
- **Current Result**: `complexity gate: OK` (0 violations).

---

## 5. Security & Privacy Audit Compliance

As documented in [`docs/SECURITY_AUDIT.md`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/docs/SECURITY_AUDIT.md):

1. **Filesystem Permissions**:
   - Local token and pinned chat cache stored in `~/.local/state/omarchy/plugins/denial.beeper-relay/`.
   - State directory enforced at mode `0700` (`rwx------`).
   - Token file `token.json` and snapshot file `pins.json` enforced at mode `0600` (`rw-------`).
2. **Data Minimization on Disk**:
   - [`stripPreviewsForStorage()`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/models/TriageModel.js#L201) strips all message bodies, preview texts, sender information, and timestamps before writing retained pinned chat snapshots to disk.
   - Pinned chat snapshots on disk contain only metadata IDs and title strings.
3. **No Sensitive Data Leaks**:
   - Zero logging of authorization tokens, Bearer headers, or message bodies to `stdout`, `stderr`, or system journals.
   - Local IPC target `manageIpc: false` prevents unauthorized cross-plugin IPC tampering.

---

## 6. Manifest & Marketplace Verification

[`manifest.json`](file:///home/denial/.config/omarchy/plugins/denial.beeper-relay/manifest.json) validation:

```bash
omarchy plugin validate ./
```
*Validation exit code: `0` (clean).*

```json
{
  "schemaVersion": 1,
  "id": "denial.beeper-relay",
  "name": "Relay",
  "version": "1.1.0",
  "author": "denial",
  "license": "MIT",
  "homepage": "https://github.com/denialbb/relay",
  "description": "Keyboard-first unread Beeper triage drawer.",
  "kinds": [
    "bar-widget"
  ],
  "entryPoints": {
    "barWidget": "BarWidget.qml"
  },
  "barWidget": {
    "displayName": "Relay",
    "description": "Beeper unread triage drawer",
    "category": "Communication",
    "aliases": [
      "beeper",
      "chat",
      "messages",
      "matrix",
      "whatsapp",
      "telegram",
      "triage",
      "relay"
    ],
    "allowMultiple": false,
    "defaultSection": "right"
  }
}
```

---

## 7. Reviewer Verification Steps

To verify Relay in an Omarchy environment:

1. **Install Plugin**:
   ```bash
   omarchy plugin add https://github.com/denialbb/relay --enable
   ```
2. **Run Offline Test & Gate Suite**:
   ```bash
   cd ~/.config/omarchy/plugins/denial.beeper-relay
   make check
   ```
3. **Launch & Triage**:
   - Ensure Beeper Desktop is running.
   - Click the Relay bar icon (`󰍡`) or bind a shortcut to open the panel.
   - Use `j` / `k` to navigate unread chats.
   - Press `i` to open the rounded inline quick reply; type a response and press `Enter` to send.
   - Press `r` to mark a chat read; verify zero visual flicker on retained pinned chats.
   - Press `Ctrl+J` / `Ctrl+K` to dynamically resize the drawer height.
   - Press `?` to toggle full keyboard hints.
   - Press `Esc` or `q` to dismiss.
