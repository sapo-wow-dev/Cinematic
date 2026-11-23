# Settings: the Chat page's tabs turn their rows off (fix card, retroactive)
Fix: the Chat page's Conversations, Game Messages and Channels tabs switched off (a right-click) stopped nothing: their
rows are list rows, never hung under the tab's switch, and UI/Chat.lua read them raw.
Found by: audit 2026-11-22; fixed in bdb2e1d
Code: UI/Chat.lua: IsPeekTypeOn, IsChannelPeekNow (PEEK_TAB, TabOff)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: Conversations tab off, a whisper still brought the chat window up (and so for a skill-up with Game Messages
  off, a Trade line with Channels off).
- After: a tab off = none of its rows show the chat; the other tabs' rows as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsPeekTypeOn IsChannelPeekNow CHAT_CHANNELS_TAB tabOn:Chat/page:2`)
- Players: anyone who right-clicked a Chat content tab off (tabs default on) and still relied on its rows.
- Other features: the server-announcement peek (UI/Chat.lua: IsPeekTypeOn("server"), now under Game Messages), quest
  lines, level-up and /who lines (all through IsPeekTypeOn). The tab's rows: Options.lua TypeSection (section "game"
  = tab 3, the rest tab 2), matching PEEK_TAB.
- Other addons: none.
- Tests that encode it: Tools/offline/auditsettings.lua check 1 (kept).

## States (the matrix)
page made yet (no / yes) x the row (a whisper: Conversations, a skill-up: Game Messages, a Trade line: Channels) x the
page's switch x the tabs (all on / the row's own off / another off) x the row's Always or Never, per client. Each cell
runs the game's chat filter (ChatPeekFilter). 72 cells.
Test: Tools/offline/chattabsmatrix.lua forever
Test: Tools/offline/chattabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chattabs-rows | pageSwitch=on tabs=ownOff rowSet=always | peek | none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: retroactive. Not proven offline: the bubble wait (PeekUnlessBubble is counted, not run), Show in rules other than
Always/Never (RowOnNow), the in-game right-click on a tab. TabOff reads the tab's saved value only (not ns.Setting):
right while the tabs hang under the page (handleChat, checked first by the filter).
