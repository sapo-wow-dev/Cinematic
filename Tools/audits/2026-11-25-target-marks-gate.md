# Nameplates: the target marks' loop rests with Nameplate Style's Smart page or Enable Style off (fix card)
Fix: the target marks were wanted (their level up, their When loop running every half second) with the page that draws them off
Found by: the gating in-game test, run 1 (testQueue_qd001, Forever, 2026-11-25): PlateParts.lua:3309 x4 with Nameplates off, x8 with every switch off
Code: Plates/PlateIcons.lua: ns.PlateIconWanted
Clients: both
Base: d6145ed

## Before / after
- Before: Always ticked on the marks' row, Enable Style or Nameplate Style's Smart page (plateMarks) off: no
  mark drew (RefreshTargetArrow asks ns.StyleOn("plateMarks")), but their level stayed up and their When
  loop kept checking the rows twice a second, refreshing every plate's mark.
- After: not wanted there, so the level goes to 0 and the loop rests. With the Smart page on, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateIconWanted TargetArrow`)
- Players: none see a change (nothing drew). The Nameplates page off still leaves the marks to their own row
  (they're a Style page's), as before.
- Other features: PlateParts.lua's levels (the only reader), the aggro and distance rows' checks under it.
- Tests that encode it: platefullmatrix, heldpartsmatrix, calmplatesmatrix, platetabsmatrix, platepartsidlematrix.

## States (the matrix)
Enable Style on or off, the Smart page on or off, the marks' Always tick on or off, in CineMode; the client.
Test: Tools/offline/targetmarksgatematrix.lua forever
Test: Tools/offline/targetmarksgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| target-marks-gate | style=off always=on | wanted | not wanted |
| target-marks-gate | style=on smart=off always=on | wanted | not wanted |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one condition; the marks couldn't draw in those cells anyway.
