# Errors text: left alone with both hide boxes off (fix card)
Fix: with both Hide errors boxes off, every settings pass wrote the red error text's opacity back to full, over whatever another addon (or the game) had set
Found by: audit 2026-11-25 (gating, finding E5; decided: write 1 back only if Cinematic last set 0)
Code: Effects.lua: ns.UpdateCVars (the UIErrorsFrame lines), ns.errorsHiddenByUs (new)
Clients: both
Base: baabf86

## Before / after
- Before: both boxes off (the default): each pass (twice a second and on every change) set the error
  frame's alpha to 1, undoing another addon that fades or hides it.
- After: we set 0 while a box hides it, set 1 once when it stops hiding, and otherwise never touch it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UIErrorsFrame hideErrorsInCombat hideErrorsOutOfCombat`)
- Players: with a box on, the same; with both off, the game's (or another addon's) own alpha stays.
- Other features: none set UIErrorsFrame's alpha.
- Other addons: those fading UIErrorsFrame now keep their alpha.
- Tests that encode it: none.

## States (the matrix)
The boxes on or off; before that, our pass hid it or not; another addon's 0.5 under it.
Test: Tools/offline/errorsalphamatrix.lua forever
Test: Tools/offline/errorsalphamatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| errors-alpha | box=off before=none | alpha=1 | alpha=0.5 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a reload while hidden by us leaves the frame at the game's own 1 anyway (frames aren't saved). An
addon that set it to 0 before a box was ticked gets 1 when the box is unticked (as before). Not proven
offline: the real error frame in a fight.
