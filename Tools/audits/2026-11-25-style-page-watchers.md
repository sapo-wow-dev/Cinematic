# Style: Unit Frames and Action Bar Style rest while their pages are off (fix card)
Fix: with Unit Frames Style off, every target, focus and group change still dressed every unit frame (and its bar hooks were installed and ran); with Action Bar Style off (or not round), every cast was watched and the Cooldown Manager's viewers were hooked
Found by: audit 2026-11-25 (gating, finding D10 in 2026-11-25-gating-findings.md)
Code: Style/UnitStyle.lua: DressFrame, its "Unit power keep" hook, ns.RefreshUnitStyle; Style/ActionBarStyle.lua: castWatch (WatchCasts, new), RoundGlow, ns.RefreshCooldownShape
Clients: both
Base: baabf86

## Before / after
- Before: Unit Frames Style off: each target, focus, pet, power type or group change ran the whole dress of
  every unit frame, putting back what was already the game's (and the heal forecast's alpha written to 1
  each time); the first such pass installed the frames' bar hooks, and the power bar's keep hook ran on each
  power tick. Action Bar Style off, or its Shape not Round: six cast events and four button-state events
  were watched for good, each walking every button; the Cooldown Manager's viewers were hooked at login and
  walked every icon on each layout.
- After: Unit Frames Style off from login: nothing runs, no hooks; switched off: put back by the refresh and
  its settling pass (not in a fight: then at its end), then left be, the keep hook out at its first line.
  Action Bar Style: casts watched only while a round glow is on a button; the viewers hooked the first time
  Round is used, and walked only while Round is on or just went off. Pages on: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshUnitStyle DressFrame RefreshCooldownShape SyncAllGlows`)
- Players: none see a change: with the pages off these passes only put back the game's look.
- Other features: ns.RefreshUnitStyle's callers (the page, themes, profiles, Edit Mode, the watcher, the
  ToT/ToF frames' later.Dress) all run the same gate; UnitAuraLift's own gate is its own fix (D15). The
  heal forecast's alpha is no longer set to 1 by us with the page off (the game's own stands).
- Other addons: none.
- Tests that encode it: totredressmatrix's look=off cells pinned "dressed=few" (a page-off frame dressed a
  few times a second): now "none". Below, for the user's OK. auralift, auraplate, castframe, castlook,
  followhud, rankdragon, selfframetheme, selfpairprobe, stylepagegatematrix, unitmatch, cdmiconshape,
  cdmpandemicmatrix, cdmroundmatrix, cooldownlinesmatrix, profilekeepmatrix: PASS, both clients.

## States (the matrix)
A login with Unit Frames Style on, off, or on then switched off; a target change. A login with Action Bar
Style on or off, Round or Square, then switched off or kept; the client. And the ToT frame's own matrix.
Test: Tools/offline/stylehooksmatrix.lua forever
Test: Tools/offline/stylehooksmatrix.lua retail
Test: Tools/offline/totredressmatrix.lua forever
Test: Tools/offline/totredressmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| unit-style-watch | page=offFromStart | dressed | none |
| unit-style-watch | page=onThenOff | dressed | none |
| action-bar-watch | page=on shape=round after=pageOff | casts=watched viewer=hooked | casts=none viewer=hooked |
| action-bar-watch | page=on shape=square | casts=watched viewer=hooked | casts=none viewer=none |
| action-bar-watch | page=off | casts=watched viewer=hooked | casts=none viewer=none |
| tot-redress | look=off | * | * |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/totredressmatrix.lua | look=off cells (6): how often the frame was dressed with Unit Frames off | dressed=few | dressed=none | yes, the user 2026-11-25 (picked "3 Unit Style"); pin edited |

## Risk
low: the gate only skips while the page is off and its put-back passes are done. Not proven offline: the
real unit frames put back on the page's flip in a fight (the settling pass keeps the flag till a fight ends,
then the fight-end refresh puts back), and the round glow's casts watched again as Round is picked (offline
the button's dress runs on a stand-in).
