# Chat: a copied line over a full chat window (fix card)
Fix: with Show just those messages, a newer line under the copied one went unnoticed once the chat window held its full 128 lines, so the copy crossed over a different line as chat came up.
Found by: audit 2026-11-23
Code: UI/Chat.lua: CopyLinesUp, ShowCopy (new WindowMark, LinesSince)
Clients: both
Base: 8d185cd

## Before / after
- Before: after a long session (128 lines in the chat window: an hour in a city), a message shows on its own; loot or another channel's line comes in under it; you mouse over chat. The copy slowly fades across the window's newest line, which is a different message: two texts on top of each other. A fresh window (fewer than 128 lines) did it right: the copy went in a quick fade.
- After: full or not, a newer line under the copy makes it go in the quick fade as the window comes up. With nothing newer, it still crosses over the window's own line.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CopyLinesUp ChatCopyState chatPeekLinesOnly`)
- Players: everyone with Show just those messages on (on by default, the game's own chat only).
- Other features: none; CopyLinesUp is read only by WatchCopies and ns.ChatCopyState.
- Other addons: none (lines-only is off with another chat addon: ns.ChatIsDefault).
- Tests that encode it: Dev/ChatRevealTest.lua (/cine debug chatreveal) reads linesUp/count, same meaning; Dev/ChatDefaultTest.lua logs count. copy.count is kept as it was. No offline check, ledger or engine rule.

## States (the matrix)
The window's lines (a few, or full at 128), a line after the copied one (none, someone else's, the same line again), scrolled to the bottom or not; then the window rises.
Test: Tools/offline/chatcopymatrix.lua forever
Test: Tools/offline/chatcopymatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chatcopy-rise | lines=full newer=other bottom=yes | first=shown rise=crossing | first=shown rise=gone |
| chatcopy-rise | lines=full newer=same bottom=yes | first=shown rise=crossing | first=shown rise=gone |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only how the copy leaves as chat comes up. Pinned: all 12 cells both clients. Not proven offline: the game's real 128-line window and its GetMessageInfo order (read from Blizzard_SharedXML/ScrollingMessageFrame.lua, newest = index count), and a secret line on Forever (the mark is then nil and the copy goes in the quick fade, as an unreadable count did before).
