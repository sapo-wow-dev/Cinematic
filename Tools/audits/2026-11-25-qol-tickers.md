# Reload button and Addon Conflicts: no timers running for nothing (fix card)
Fix: the Reload button's timer ran twice a second for every player for good (on Forever building the Reload key's binding text each time), and the Addon Conflicts timer plus five chat events ran for good once any conflict row existed, every pick Theirs too
Found by: audit 2026-11-25 (gating, finding D15: Reload's 0.5 s ticker, Conflicts' ticker)
Code: QoL/Reload.lua: KeyOn, BindKey, OutOfStep (new), the button's events, the timer -> ns.FeatureLoop; Conflicts.lua: HoldsWanted (new), ns.OnConflictAdded, ns.SetConflictPick
Clients: both (the Reload key: Forever only)
Base: baabf86

## Before / after
- Before: the Reload button's check ran every half second for the whole session, with the button off;
  with an addon that has a conflict row loaded (ElvUI, DynamicCam, RareScanner...), its holds were looked
  at every half second and after each say, yell or party line, every pick Theirs.
- After: the button and key are put right as their settings change (looked at once a second with the
  other feature loops, the key also when bindings change or a fight ends). The conflict holds run only
  while a row that hides frames has Ours picked, or a frame is still held to let go.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UpdateConflictHolds OnConflictAdded reloadButton CINEMATIC_RELOAD`)
- Players: the button shows and hides as before (within a second); the key works as before. Ours picks
  hold as before.
- Other features: ns.reloadTestShowButton (Dev) is looked at the same way.
- Other addons: their Support/ conflict rows: held as before with Ours.
- Tests that encode it: euiyields.lua and selftextstyle.lua (conflict picks): still PASS.

## States (the matrix)
reload-key: the tick, its page, the Keybinds tab's Reload key switch. conflict-holds: the row's pick,
its addon's version on or off.
Test: Tools/offline/qoltickersmatrix.lua forever
Test: Tools/offline/qoltickersmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| reload-key | tick=on page=on keytab=on | button=shown reads=yes | button=shown reads=no |
| reload-key | keytab=on tick=off | button=hidden reads=yes | button=hidden reads=no |
| reload-key | keytab=on page=off | button=hidden reads=yes | button=hidden reads=no |
| conflict-holds | pick=theirs | held=no looked=yes | held=no looked=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the same Update and holds, run on change rather than on a clock. A binding changed by another addon
without UPDATE_BINDINGS would wait for the next settings change (the game fires it for every binding
change). Ours picked from another profile's saved picks is seen within a second. Not proven offline: the
secure Reload key on Forever after a fight, and a real addon's conflict frames.
