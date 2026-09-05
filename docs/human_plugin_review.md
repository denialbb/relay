# Human Report on Relay plugin

## BUGS

- trying to 'open in beeper', both 'o' binding and clicking
  - opens 2 instances of chrome, does NOT open the selected
    chat/message in the beeper desktop app
- 'mark as read' does not work
- channels (where no message can be sent, read only) are showing up - this is
  OUT of the plugin scope, should be removed
  - examples: 'Tabz - Live News', 'Rai News', etc
- in open chats there is a duplicated header with the chat name, integrate the
  both of them
  - keep the top one as it is better styled
- align to the right side the messages from the user in chats
- most chats are missing in the drawer
- only DMs showing are from 'Federico' and 'Ivan'
  - these are old chats, not up to date with beeper
- any change in this plugin's folder seems to trigger a reload of the whole
  quickshell env (I see a flicker any time I save this file for example) this is
  very annoying, fix this auto refresh

## NOTES

- bind 'q' in addition to 'Esc' for quitting/going back to the chat list - show
  only q in the help at the bottom of the drawer
- bind 'o' to open the chat, 'b' for beeper, keep enter as well but don't write
  it in the help at the bottom
- add 'i' binding that jumps to the input box in a chat
- add 'i' binding for quick answer in the message list screen
  - pop open a bottom input box, on enter send the message, mark as read the
    chat, remove from the message list
- add scrolling 'j/k' in the chat screen (smooth scrolling)
- add to the list the 'VAULT' chat in beeper, this is a personal chat we can use
  for testing
- compress a bit the bottom help labels, the are overflowing outside the drawer
  width
