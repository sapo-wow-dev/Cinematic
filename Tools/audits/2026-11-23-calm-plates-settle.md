# Nameplates: the plates pass settles through the Calm Timer (fix card)
Fix: in CineMode with a kind ticked for fights, the whole plates pass ran every tick of every Calm Timer (~27 a second) though nothing moved
Found by: /perf 2026-11-23 (Forever deep fight recording 17:10, UpdatePlates 0.29 ms a frame, +0.20 since 2026-11-22)
Code: Effects.lua: ns.UpdatePlates (the held-after-a-fight branch), ns.plates.SameAsBefore
Clients: both
Base: e08f3c3

## Before / after
- Before: after a fight, kinds not ticked for fights held at 0 through the Calm Timer didn't count as settled (only a fight's did, since 2026-11-21), so the pass never went quiet: all of it on every tick for the whole Calm Timer.
- After: held at 0 counts as settled, like in a fight. The pass then skips like any settled one (0.5 s re-check), and the Calm Timer ending (or cut) is one of SameAsBefore's inputs, so the plates still start fading on the first tick after it. What the player sees is the same, tick by tick.

## Who relies on the old behavior
- Players: no setting changes; plates look the same in every matrix cell.
- Other features: ns.plates.quiet / settled / rollOnly readers (Effects.lua only); the pass's skip is the same one fights use since 2026-11-21.
- Other addons: none (no plate set or frame changes).
- Tests that encode it: farnamesmatrix.lua, check.lua's plate passes (run, unchanged).

## States (the matrix)
CineMode on/off, a kind ticked for fights (Enemies) or none, Neutral NPCs (not for fights) kept up where you are or not, and the point of the run: in a fight, 1 s into the Calm Timer, 6 s in, 0.1 s after it ends, 4 s after. Each cell: Neutral NPCs' limit, the plates' fade level, and whether the pass ran on most ticks of the second before.
Test: Tools/offline/calmplatesmatrix.lua forever
Test: Tools/offline/calmplatesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| calm-plates-settle | cine=on fightKind=on kept=off phase=calmStart | cap=0.00 level=1.00 pass=busy | cap=0.00 level=1.00 pass=quiet |
| calm-plates-settle | cine=on fightKind=on kept=off phase=calmSettled | cap=0.00 level=1.00 pass=busy | cap=0.00 level=1.00 pass=quiet |
| calm-plates-settle | cine=on fightKind=on kept=off phase=calmEnded | cap=0.00 level=0.90 pass=busy | cap=0.00 level=0.90 pass=quiet |
| calm-plates-settle | cine=on fightKind=on kept=on phase=calmSettled | cap=- level=1.00 pass=busy | cap=- level=1.00 pass=quiet |
| calm-plates-settle | cine=on fightKind=on kept=on phase=calmEnded | cap=- level=0.90 pass=busy | cap=- level=0.90 pass=quiet |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low-medium: a rule or setting that changes a kind's "kept here" mid-Calm Timer is picked up within 0.5 s (the settled re-check) instead of at once; target, focus, mouseover, markers and plates coming and going still bring a pass at once (the same as in fights today). Not proven offline: the real tick's other callers and a live Calm Timer cut (ns.OnCalmEnd) in game; a normal /cine profiler fight run measures the saving.
