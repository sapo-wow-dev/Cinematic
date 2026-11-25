# Quest Vision: Quest Talk's loops stop when it can't show (fix card)
Fix: with Quest Vision off, held to CineMode out of it, or in gamepad mode with the game's windows, Quest
Talk's follower still ran every frame (and its watcher five times a second), kept alive by the raw tick
Found by: audit 2026-11-25 (gating, finding D16 in 2026-11-25-gating-findings.md)
Code: Visions/QuestTalk.lua: QuestTalkLoopWanted, ns.WakeQuestTalkLoops (new), ns.RefreshQuestTalk, the
talk's open; Core.lua: ns.RefreshOutsideCine's list
Clients: both
Base: baabf86

## Before / after
- Before: Quest talk ticked but its page off (or Allow outside CineMode unticked with CineMode off, or a
  gamepad with "the game's windows" picked): no bubble can come, but its follower read your facing, the
  camera and the mouse every frame, and its watcher looked at the game's windows five times a second.
- After: both loops run only while Quest talk can show (or one of ours is still up or fading out); a talk
  opening, the page's refresh or CineMode changing wakes them at once.

## Who relies on the old behavior
(`python -I Tools/audit.py refs QuestTalkLoopWanted RefreshQuestTalk questTalk`)
- Players: nothing on screen changes: the talk only opens with Setting("questTalk") on (QuestTalk.lua's
  open, 2583), and a talk up or fading keeps both loops wanted as before.
- Other features: the lockout watcher (the game's window parked with nothing of ours) still runs while a
  talk is up or Quest talk is on; ParkWindows only parks with Setting("questTalk") on.
- Other addons: none.
- Tests that encode it: questtalk offline checks (run, unchanged).

## States (the matrix)
Quest Vision's page, its Quest talk tick, CineMode, Allow outside CineMode, gamepad with questTalkPadGame.
Test: Tools/offline/questtalkloopmatrix.lua forever
Test: Tools/offline/questtalkloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| quest-talk-loops | page=off talk=on | follower=on watcher=on | follower=off watcher=off |
| quest-talk-loops | page=on talk=on pad=game | follower=on watcher=on | follower=off watcher=off |
| quest-talk-loops | page=on talk=on cine=off outside=off pad=no | follower=on watcher=on | follower=off watcher=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the loops only do work with a talk up. Not proven offline: a real talk opening right after CineMode
comes on (the wake at the open covers the gap till the once-a-second check), and the gamepad switch live.
