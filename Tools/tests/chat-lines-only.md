# Show just those messages (chat lines only): test ledger
Goal: a message that brings up chat shows only its own line, where the window sits, and hands over cleanly to the window when you mouse over chat.
Code: UI/Chat.lua (FindWindowLine, PlainParts, WindowMark, LinesSince, CopyLinesUp, ShowCopy, PeekLine), Dev/ChatRevealTest.lua (/cine debug chatreveal), Dev/ChatDefaultTest.lua (/cine debug chatdefault)
Audit 2026-11-23: fix cards Tools/audits/2026-11-23-chat-copy-full-window.md (b34bd34), 2026-11-23-chat-copy-find-line.md (13e6aaf); offline Tools/offline/chatcopymatrix.lua, chatfindmatrix.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | How many lines does a game chat window keep, and does GetNumMessages stop growing there? | both | 128 (SetMaxLines(128)); count = history buffer elements, so it stays 128 once full | ChatFrameOverrides.lua:3, Blizzard_SharedXML/ScrollingMessageFrame.lua:26 |
| Q2 | GetMessageInfo(GetNumMessages()) is the newest line? | both | YES: index N = the buffer's front (PushFront on AddMessage) | ScrollingMessageFrame.lua:9-33 |
| Q3 | Does the game send achievements as "%s has earned..." and show the name in its place? | forever | YES: AddMessage(arg1:format(GetPlayerLink(...))) | ChatFrameOverrides.lua:425-429 |
| Q4 | With a full window (128 lines), a newer line under the copy: quick fade on mouse over? | forever | YES: other and same line under it, copy gone by 0.4 s; nothing newer, copy at 0.50 crossing | run 1 step full |
| Q5 | An achievement (Achievements row on) shows just its line, not the window? | forever | YES: copy = the window's line, window stayed faded (GetAchievementLink(6) read nil at level 2: a stand-in link) | run 1 step achieve |
| Q6 | A message a filter addon blocks after ours: no older line shown? | forever | YES: landed shows the new line; blocked shows no old line, the whole window peeks | run 1 step blocked |
| Q7 | Any line on Forever reading secret, so the mark is nil (falls back to the old search)? | forever | out of fights NO: 20 of 20 of your chat's lines plain, GetMaxLines 128; in fights open (not needed: a secret mark falls back to the old search) | run 1 step setup |

## Plan tree (step 3)
All PASS -> done; mark the steps proven. Q4 FAIL (copy still crosses on a full window) -> the real frame's GetMessageInfo order or count differs from the mixin read: the step's log lines (windowCount, linesUp) say which; fix LinesSince. Q5 FAIL -> the copy line vs the window line in the log show what the loose match missed. Q6 FAIL with copy=old -> the mark wasn't taken before the line (the order of filter and AddMessage). Q7 secret lines -> the mark is nil there and the old search runs: note it in the rules, no build change.
Test: Dev/ChatLinesTest.lua (/cine debug chatlines, kit, hands off): a test window from the game's own ScrollingMessageFrame (128 lines), driven through Chat.lua's test hooks; never the player's chat. Offline dry run 7 PASS both clients.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug chatlines (queue qd892) | Q4-Q7 on Forever, 7 PASS, 0 errors/blocked | retail not run (Forever is the test client); Q7 in fights not reached |
