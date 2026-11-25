# Chat: the Conversations tab off stops typing bringing the chat windows up (fix card)
Fix: the Typing row sits on the Chat page's Conversations tab, but with that tab off, typing still brought the whole chat window up
Found by: audit 2026-11-25 (gating, finding C6 in 2026-11-25-gating-findings.md)
Code: Frames.lua: ns.UpdateFrames (typingWindows)
Clients: both
Base: baabf86

## Before / after
- Before: Show chat while typing on, then the Chat page's Conversations tab right-clicked off: pressing
  Enter in CineMode still brought the chat windows up, tabs and all.
- After: with that tab off, only the input box comes up, as with the row off.

## Who relies on the old behavior
(`python -I Tools/audit.py refs chatShowWhileTyping chat:typing`)
- Players: none want a switched-off tab's row kept.
- Other features: Hover groups with Typing ticked (events.typing) go by the same value: off with the tab
  too. The input box itself (activeEditBox) still comes up.
- Other addons: ElvUI chat panels (MarkChatHolders): unchanged.
- Tests that encode it: chatbgsettle, chattabsmatrix, lazytabsmatrix: PASS both clients.

## States (the matrix)
The Chat page's switch, its Conversations tab, and the Typing row, each on or off; typing in CineMode.
Test: Tools/offline/chattypingmatrix.lua forever
Test: Tools/offline/chattypingmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chat-typing | page=on tab=off row=on | up | down |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more condition, true with the tab on (its default). Not proven offline: a real Enter press with
the tab off (the input box alone).
