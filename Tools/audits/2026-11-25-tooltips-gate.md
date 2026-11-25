# Tooltips: no fade or After countdown with Mouseover's Show off (fix card)
Fix: with Mouseover's Show tab off (the switch the Tooltips page is under), tooltips still faded in and out, the After countdown still ran and No wait for still looked units up
Found by: audit 2026-11-25 (gating, finding C13 in 2026-11-25-gating-findings.md)
Code: UI/TooltipParts.lua: PageOn (new), Cut, FadeTime, StartCountdown, SkipsWait
Clients: both
Base: baabf86

## Before / after
- Before: Tooltips page on with Fade in/out and After set. Turn Mouseover's Show tab off: the page greys,
  its lines are no longer taken out (Cut already checked it), but the tooltip still fades in and out, and
  after the After seconds it fades out and back in for nothing.
- After: with Mouseover's Show off, tooltips are left as the game has them: no fade, no countdown, no No
  wait lookups. On again: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FadeTime StartCountdown SkipsWait handleTooltips`)
- Players: those with Mouseover's Show off and the Tooltips page on (greyed for them).
- Other features: none read these locals.
- Other addons: none.
- Tests that encode it: tooltipnowait.lua (all switches on: unchanged), tooltipfaction, tooltiplocation.

## States (the matrix)
The Tooltips page on or off, Mouseover's Show on or off; the game shows its tooltip.
Test: Tools/offline/tooltipgatematrix.lua forever
Test: Tools/offline/tooltipgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| tooltips-gate | page=on show=off | fade=yes countdown=yes | fade=no countdown=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/tooltipnowait.lua | checks 1, 3, 4, 5, 5b, 7 (setup never turned Mouseover's Show on) | skips | waits (fixed: setup gets mouseover = true, then skips again) | yes, the user 2026-11-25 (picked "2 Tooltip tests") |
| Tools/offline/questiegatematrix.lua | questie=login/late box=on/unticked cells (same setup) | asks=tip,wait,item,mark,icon | asks=tip,item,mark,icon (fixed: setup gets mouseover = true) | yes, the user 2026-11-25 (picked "2 Tooltip tests") |

## Risk
low: one more condition, the one Cut already used. Not proven offline: a real hover with the switch off
(the matrix calls the OnShow hook directly).
