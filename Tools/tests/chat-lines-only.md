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
| Q4 | With a full window (128 lines), a newer line under the copy: quick fade on mouse over? | both | open (offline yes: chatcopymatrix) | next chatreveal run |
| Q5 | An achievement (Achievements row on) shows just its line, not the window? | both | open (offline yes: chatfindmatrix) | next run |
| Q6 | A message a filter addon blocks after ours: no older line shown? | both | open (offline yes; needs a blocking filter, the test can add one of its own) | next run |
| Q7 | Any line on Forever reading secret, so the mark is nil (falls back to the old search)? | forever | open | next run |
