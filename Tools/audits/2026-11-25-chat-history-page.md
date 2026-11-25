# QoL: chat history kept while its page is off (fix card)
Fix: logging in with the Quality of life page off wiped the saved chat history, though Keep chat history was still ticked
Found by: audit 2026-11-25 (gating, finding B3 in 2026-11-25-gating-findings.md)
Code: UI/ChatCopy.lua: the history loader (PLAYER_LOGIN)
Clients: both
Base: badf2f0

## Before / after
- Before: Keep chat history ticked, the Quality of life page switched off for a session: at login the saved
  lines were deleted, so turning the page back on brought nothing back.
- After: with the page off, nothing is shown or added (as before), but the saved lines stay; with the page
  on again, they're back. Only unticking Keep chat history itself deletes them. (The user picked no
  preference on 2026-11-25; the recommended option was taken.)

## Who relies on the old behavior
(`python -I Tools/audit.py refs chatHistory`)
- Players: those who turned the page off to stop the history: it stops (nothing shown or saved), the old
  lines stay on disk till the tick is off or they age out (HISTORY_AGE).
- Other features: SaveLine checks ns.Setting("chatHistory") (unchanged); /cine debug chathistory reads it.
- Tests that encode it: none.

## States (the matrix)
Keep chat history ticked or not, the Quality of life page on or off, at login with a saved line; the client.
Test: Tools/offline/chathistorymatrix.lua forever
Test: Tools/offline/chathistorymatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chat-history-login | tick=on page=off | shown=no kept=no | shown=no kept=yes |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only the page-off login changes, from deleting to keeping. The restore is now also gated on the
setting (before, the wipe hid that it wasn't). Not proven in game: a real login's saved lines.
