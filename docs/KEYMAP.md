# Relay — Keyboard Reference

Relay is designed as an unread triage tool operated entirely from the keyboard.

---

## 1. Primary Shortcuts

| Shortcut | View Context | Function |
|---|---|---|
| `j` or `Down` | Chat List | Navigate to next unread chat |
| `k` or `Up` | Chat List | Navigate to previous unread chat |
| `Enter` | Chat List | Open selected chat conversation view |
| `Esc` | Chat List | Dismiss / close triage drawer |
| `Esc` | Conversation | Back to unread chat list |
| `r` | Chat List / Conversation | Explicitly mark active chat as read |
| `c` | Conversation | Jump focus into reply composer |
| `Ctrl + Enter` | Composer | Send message |
| `o` | Any | Open chat in Beeper Desktop client |

---

## 2. Interaction Design Rules

1. **No Implicit Read**: Merely highlighting or opening a conversation **never** marks the chat as read. The user must explicitly press `r` or reply.
2. **Cursor vs Mouse Isolation**: Mouse hover alters the hovered item's visual background, but **never** mutates the keyboard selection cursor (`selectedIndex`). This prevents focus hopping during rapid `j`/`k` keyboard scrolling.
3. **Modal Isolation**:
   - In Chat List mode, all single-letter keys (`j`, `k`, `r`, `o`) trigger triage actions.
   - In Composer mode, typing text routes to the input field; navigation shortcuts are suppressed until `Esc` or `Ctrl+Enter` is pressed.
4. **Key Hints Footer**: The bottom bar dynamically updates to show available keyboard operations relevant to the active context (Chat List, Conversation, or Error state).
