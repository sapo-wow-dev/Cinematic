# Nameplates: plate parts held on a plate that isn't up are let go (fix card)
Fix: plate parts faded by Cinematic stayed held (at 0) after their plate went with no removal seen: the keeper ran every frame for them, and a pooled plate came back with them hidden
Found by: the in-game gating test, run 7 (testQueue_q3ad8, Forever, a town, 2026-11-25): the probe saw 54 parts held at 0, every one "at=no plate", PlateParts.lua:144 x341 with every switch off; runs 3 too (x341), 4-6 not (fewer plates)
Code: Plates/PlateParts.lua: the Plate parts keeper's sweep (LetGoOrphans)
Clients: both
Base: 7acf92f

## Before / after
- Before: a part (a name, the classification icon, the health bar's border, crowd control...) faded to 0 by a
  row stayed held when its plate left without NAME_PLATE_UNIT_REMOVED reaching our let-go (cause in game not
  pinned: the removal handler lets go, the offline stand-in never reproduced it). The keeper put it back to 0
  twice a second for good, with every switch off too; a pooled plate given a new unit later could show with
  those parts gone until the next pass faded or let them go.
- After: the keeper's half-second sweep lets go of every held part no shown plate has, as a removed plate's
  are (LetGo, "a plate gone: its parts let go... a new unit on it is faded again at once"). Every part is
  faded through EachPartFrame on a shown plate, so one not found there now is no plate's.

## Who relies on the old behavior
(`python -I Tools/audit.py refs platePartsKept LetGo EachPartFrame`)
- Players: none want a hidden plate's parts kept faded; plates up are unchanged (held as before).
- Other features: the only fade path is ApplyPlate's EachPartFrame(..., Fade); Heal Vision reads parts through
  ns.PlatePartFrames but doesn't hold them. A part whose frame changed (fallback to primary) is let go and
  faded again on the next apply, as for a new plate.
- Tests that encode it: Tools/offline/platekeeper.lua fades parts on stand-in plates it never shows (no
  C_NamePlate.GetNamePlates): its setup needs its plates shown (see Expectations changed).

## States (the matrix)
The plate up or gone (no removal heard), the part faded to 0 or 0.4, then a sweep; the client.
Test: Tools/offline/plateorphanmatrix.lua forever
Test: Tools/offline/plateorphanmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-orphan-parts | plate=gone | * | let go 1.0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/platekeeper.lua | its stand-in plates (never in C_NamePlate.GetNamePlates) | treated as up | let go as no plate's by the sweep; setup now lists its plates as shown, removed ones not | yes, the user 2026-11-25 ("Yes, edit it"); its checks unchanged |

## Risk
low: the sweep runs only while something is held (the keeper shown), twice a second, over the plates up.
Not proven in game: the parts coming back on a reused plate; the 54-part state itself (next gating run's
probe should show 0 held).
