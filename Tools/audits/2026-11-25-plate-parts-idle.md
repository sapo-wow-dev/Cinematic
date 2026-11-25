# Nameplates: the plate parts pass rests with the Nameplates page off (fix card)
Fix: with the Nameplates page off, the plate parts pass (Plates/PlateParts.lua's ns.UpdatePlateParts, from
ns.UpdatePlates every rest tick) still ran all its loops each tick: every part, every kind with parts of its own
(each asking the Style overrides again), every icon, though nothing could change.
Found by: audit 2026-11-25 (gating, finding D15: "plate parts loop with the page off")
Code: Plates/PlateParts.lua: ns.UpdatePlateParts
Clients: both
Base: baabf86

## Before / after
- Before: page off, nothing overriding, all settled: each tick 11 Style override reads, 11 more per kind with custom
  parts, 7 icon rows, and the level bookkeeping. Page on: the same 11 override reads again per custom kind.
- After: the overrides are read once a tick (11), shared by the kinds. Page off, no override set and the last pass
  settled: the parts and icons loops are skipped, but for the target marks' own row (it can show with the page off);
  the quest icon, Questie and EnhanceQoL checks after them run as before. What shows: the same in every state.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UpdatePlateParts StyleOverride PlateIconWanted`)
- Players: nothing they see changes. Style Overrides acting with the Nameplates page off is kept as it is (an
  override set: the loops run).
- Other features: Effects.lua's ns.UpdatePlates (its only caller, its return value: unchanged when idle, false).
  The class and role icons are off with the page off (handlePlateIcons under handlePlates); the quest icon too.
  A kind's Use custom parts ticked while the page is off is picked up as the page comes on (all parts at full
  either way).
- Other addons: Questie's and EnhanceQoL's icons: their checks are after the skipped loops, unchanged.
- Tests that encode it: calmplatesmatrix (counts UpdatePlateParts calls, not their work: unchanged), heldpartsmatrix.

## States (the matrix)
Page on or off x a Style override on the Health bar or none x a kind with custom parts or none x the target marks'
row on or off, out of CineMode, run till settled. Each cell: the Health bar's and the marks' levels and the row
reads one more tick makes.
Test: Tools/offline/platepartsidlematrix.lua forever
Test: Tools/offline/platepartsidlematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-parts-idle | page=on custom=one override=none arrow=on | health=1.00 arrow=1.00 calls=29 | health=1.00 arrow=1.00 calls=18 |
| plate-parts-idle | page=on custom=one override=none arrow=off | health=1.00 arrow=0.00 calls=29 | health=1.00 arrow=0.00 calls=18 |
| plate-parts-idle | page=on custom=one override=hide arrow=on | health=0.00 arrow=1.00 calls=29 | health=0.00 arrow=1.00 calls=18 |
| plate-parts-idle | page=on custom=one override=hide arrow=off | health=0.00 arrow=0.00 calls=29 | health=0.00 arrow=0.00 calls=18 |
| plate-parts-idle | page=off override=none custom=none arrow=on | health=1.00 arrow=1.00 calls=18 | health=1.00 arrow=1.00 calls=12 |
| plate-parts-idle | page=off override=none custom=none arrow=off | health=1.00 arrow=0.00 calls=18 | health=1.00 arrow=0.00 calls=12 |
| plate-parts-idle | page=off override=none custom=one arrow=on | health=1.00 arrow=1.00 calls=29 | health=1.00 arrow=1.00 calls=12 |
| plate-parts-idle | page=off override=none custom=one arrow=off | health=1.00 arrow=0.00 calls=29 | health=1.00 arrow=0.00 calls=12 |
| plate-parts-idle | page=off override=hide custom=none arrow=on | health=0.00 arrow=1.00 calls=18 | health=0.00 arrow=1.00 calls=19 |
| plate-parts-idle | page=off override=hide custom=none arrow=off | health=0.00 arrow=0.00 calls=18 | health=0.00 arrow=0.00 calls=19 |
| plate-parts-idle | page=off override=hide custom=one arrow=on | health=0.00 arrow=1.00 calls=29 | health=0.00 arrow=1.00 calls=19 |
| plate-parts-idle | page=off override=hide custom=one arrow=off | health=0.00 arrow=0.00 calls=29 | health=0.00 arrow=0.00 calls=19 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the levels are the same in all 16 cells, both clients; only the reads drop. A Style override set while the page
is off wakes the loops at once (it's checked every tick). Not proven offline: the per-frame cost in game (a few
calls a tick; the audit marked it low), the target marks fading with the page off on real plates.
