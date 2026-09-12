# Relay — Beeper Triage Drawer (denial.beeper-relay)

Quickshell `panel` plugin. Triage unread Beeper DMs/groups, NOT a Beeper replacement.
Spec: `docs/relay_beeper_triage_spec.md` (v0.1, normative for MVP).

## Dependency rule (hard)

QML → TriageModel → BeeperService → BeeperApi → HTTP/Beeper Desktop.
UI never does HTTP, parses Beeper shapes, or shells out. Direct local HTTP API only;
no `beeper-desktop` CLI in production path.

## Layout

- `TriageDrawer.qml` — panel entry, layout/focus/keyboard only
- `components/` — ChatList/Row, ConversationView, MessageRow, Composer, UnsupportedMessage, EmptyState, ErrorState
- `services/BeeperApi.js` — pure integration boundary (§7.1, options-object args)
- `services/BeeperService.qml` — transport state, retry/backoff, dedup, normalization; no visual state
- `models/TriageModel.js` — pure testable helpers (no Quickshell/Wayland/net); `models/TriageModel.qml` thin boundary
- `theme/` — semantic roles + metrics only, no raw palette in components
- `tests/` — node:test, stdlib only; fixtures in `tests/fixtures/`
- `tools/check-complexity.mjs` — McCabe gate

## Contracts

- Chat types: `single`|`group` only; unread-only; plain TEXT or `unsupported` → Open in Beeper.
- Read: explicit `markActiveChatRead()`; selecting/closing never implicitly marks read.
- Send: optimistic pending → reconcile; states pending/remote/failed-retriable/failed-permanent.
- Errors explicit: beeper-unavailable|unauthorized|rate-limited|server-error|invalid-response|unknown. Never render failure as empty inbox. Never log bodies/tokens.

## Commands

`make check` = validate + lint + test + complexity. CI needs no compositor/Beeper/net.

## Complexity gates (tools/check-complexity.mjs)

General C≤8, >10 prohibited. JS domain/model ≤8, API adapter ≤8, service ≤10,
QML handler ≤5, UI helper ≤6. >2 nesting levels or type-switch → refactor to classifier/dispatch table + guard clauses.

## Commit style

`feat(model): …`, `feat(api): …`, `feat(ui): …`, `fix(service): …`, `refactor(model): …`. Small behavior commits.
