# Relay — Keyboard Reference

Relay is designed as an unread triage tool operated entirely from the keyboard.

---

## 1. Primary Shortcuts

| Shortcut | View Context | Function |
| --- | --- | --- |
| `j` or `Down` | Chat List | Navigate to next unread chat |
| `k` or `Up` | Chat List | Navigate to previous unread chat |
| `Enter` or `o` | Chat List | Open selected chat conversation view (selection defaults to first chat on load) |
| `i` | Chat List | Open quick reply inline modal (auto-expanding multiline input up to 100px) |
| `p` | Chat List / Conversation | Toggle pin on active chat (pinned chats sort first, retained across inbox clearance) |
| `h` (or `Ctrl + p`) | Chat List / Conversation | Toggle hide pinned chats (header shows `Relay · pins hidden`) |
| `r` | Chat List / Conversation | Explicitly mark active chat as read (`Ctrl + r` force-refreshes inbox) |
| `b` | Chat List / Conversation | Launch directly into Beeper Desktop (`beeper://chat/<chatId>`) |
| `?` | Any | Toggle centered key hints bar between compact and full shortcut view |
| `Esc` (or `q`) | Chat List | Dismiss / close triage drawer |
| `Esc` | Quick Reply | Cancel quick reply and return to chat list |
| `Esc` (or `q`) | Conversation | Return to unread chat list |
| `i` or `c` | Conversation | Focus reply composer |
| `j` or `Down` | Conversation | Scroll message history down |
| `k` or `Up` | Conversation | Scroll message history up |
| `Enter` | Composer / Quick Reply | Send message (shows immediate optimistic pending state with spinner) |
| `Shift + Enter` | Composer / Quick Reply | Insert newline |
| `Ctrl + j` (or `Ctrl + Down`) | Any | Grow drawer height (+50px step, animated, max 700px) |
| `Ctrl + k` (or `Ctrl + Up`) | Any | Shrink drawer height (-50px step, animated, min 220px) |

---

## 2. Interaction Design Rules

1. **Immediate Selection**: On drawer open or data refresh, keyboard selection automatically targets the first available chat (`selectedIndex: 0`).
2. **No Implicit Read**: Merely highlighting or opening a conversation **never** marks the chat as read. The user must explicitly press `r` or reply.
3. **Cursor vs Mouse Isolation**: Mouse hover alters the hovered item's visual background, but **never** mutates the keyboard selection cursor (`selectedIndex`). This prevents focus hopping during rapid `j`/`k` keyboard scrolling.
4. **Modal Isolation**:
   - **Chat List**: Single-letter keys (`j`, `k`, `o`, `i`, `p`, `h`, `r`, `b`, `?`, `q`) trigger triage actions.
   - **Quick Reply Modal**: Pressing `i` in the list opens an inline overlay with an auto-expanding multiline text field (up to 100px height). `Enter` sends; `Shift + Enter` inserts newline; `Esc` cancels.
   - **Composer**: Text entry routes to the input field; navigation shortcuts are suppressed until `Esc` (focus returns to drawer) or `Enter` (send + focus returns to drawer).
5. **Key Hints Footer**: The centered bottom bar dynamically renders an eliding formatted text summary (`formatHints`) of shortcuts appropriate to the active view (List, Quick Reply, Conversation, Onboarding, or Error). Pressing `?` toggles between compact and expanded shortcut views.

---

## 3. Pins & Priority

- **Low-Priority Filtering**: Chats marked low priority (`isLowPriority`) in Beeper are automatically filtered out of triage.
- **Pin Retention**: Pressing `p` pins the active chat. Pinned chats sort first and survive zero-unread inbox clearance (`r` marks them read without dismissing them). Pinned state persists across drawer reloads.
- **Storage Privacy**: Retained pin snapshots strip message preview text when serialized to disk (`~/.config/beeper-relay/pins.json`).
- **Hide Pinned**: Pressing `h` (or `Ctrl + p`) toggles visibility of pinned chats, switching the header title to `Relay · pins hidden`.
