# Human Report on Relay plugin

## Status & Resolution Summary

All items from the initial human review have been addressed, verified through automated unit tests (`make check` 63/63 passing) and live Wayland/Hyprland driving sessions.

### Resolved Bugs

- **Chatlist quick-reply input locking**: Fixed. Focus properly returns to the drawer on send/cancel via `releaseInputs()`.
- **Conversation view input locking**: Fixed. Sending messages from the conversation view preserves active focus navigation; Enter submits and releases inputs cleanly.
- **j/k selection unresponsiveness**: Fixed. Mouse hover is decoupled from keyboard selection cursor (`selectedIndex`), preventing focus jumping or deadlocks.

### Implemented Notes & Polish

- **Low-priority chat filtering**: `isLowPriority` chats from Beeper API are filtered out of triage.
- **Chat pinning (`p`)**:
  - Pinned chats from Beeper API are retained even with 0 unread.
  - Pressing `p` toggles local pin retention; pinned chats sort first and are never removed by `r` (mark read).
- **Pinned filter (`h` / `Ctrl+p`)**:
  - Bound to `h` (and `Ctrl+p`) for instant single-key toggle.
  - Header displays explicit `Relay · pinned` state indicator when active.
- **Pin glyph under timestamp**:
  - Minimal nerd font pin glyph (`U+F403`) positioned under the timestamp in `ChatRow`.
- **Conversation view scrolling**:
  - `j`/`k` conversation scroll speed tuned to a comfortable step.
- **Optimistic send & visual feedback**:
  - Messages display immediately with a pending state and spinner, then reconcile seamlessly on server echo. Auto-scrolls to bottom upon send.
- **Omarchy system font integration**:
  - `RelayTheme.fontFamily` inherits from `qs.Commons` `Style.font.family` (reacts to `omarchy font set`).
  - Standardized across all Text, TextInput, and TextEdit components.
- **Footer shortcut strip**:
  - Unboxed from badge boxes into a single clean eliding text strip (`key label · key label · …`) with reduced height and margins, eliminating horizontal overflow. `KeyHints.qml` retired.
