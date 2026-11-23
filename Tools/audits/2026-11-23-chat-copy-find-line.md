# Chat: the right line for a message shown on its own (fix card)
Fix: with Show just those messages, a message another addon blocked after ours showed an older line with the same words instead, and achievements never found their line, so the whole chat window came up.
Found by: audit 2026-11-23
Code: UI/Chat.lua: FindWindowLine, PlainParts, PeekLine
Clients: both
Base: b34bd34

## Before / after
- Before: a spam filter addon (or any filter after ours) blocks a message: the copy showed the newest older line with its words ("ok" from earlier, or someone else's "look", or for a "?" the sender's last line). An achievement (yours or a guild member's) always brought up the whole window: the game sends "%s has earned...", the window shows the name, and neither search matched.
- After: only lines that came into the window after the message are searched: a blocked message finds none and the whole window peeks, as for any line not found. An achievement's words on either side of the name are matched, and its line shows on its own.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CopyLinesUp ChatCopyState chatPeekLinesOnly`; FindWindowLine and PlainParts are local, read only by PeekLine and ShowCopy's formatted path.)
- Players: everyone with Show just those messages on (default, the game's own chat only). Achievements with their Always tick on (off by default) now show just the line.
- Other features: server lines (formatted path) search as before, no mark.
- Other addons: Questie's rewritten quest links still match (loose search, pinned: kind=rewritten).
- Tests that encode it: chatcopymatrix (fix card 2026-11-23-chat-copy-full-window.md, shares WindowMark/LinesSince), chatdefault, chattabsmatrix, Dev/ChatDefaultTest.lua (lines landing normally). No ledger or engine rule.

## States (the matrix)
The message kind (plain, short, no word, rewritten link, achievement), landed in the window or blocked after our filter, an older line with its words (none, the same player's, someone else's), the window a few lines or full.
Test: Tools/offline/chatfindmatrix.lua forever
Test: Tools/offline/chatfindmatrix.lua retail
Test: Tools/offline/chatcopymatrix.lua forever
Test: Tools/offline/chatcopymatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chatfind-line | landed=blocked older=same | copy=old | window |
| chatfind-line | landed=blocked older=other | copy=old | window |
| chatfind-line | kind=achievement landed=yes | window | copy=new |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the search only narrows to lines newer than the message; when where the window was up to can't be read (a secret line, cleared, over 20 new lines in one frame) it searches as before. Not proven offline: a real filter addon blocking a line, the order the game runs filters and AddMessage per window (read from ChatFrameOverrides.lua: filters, then AddMessage), and a real achievement line on both clients.
