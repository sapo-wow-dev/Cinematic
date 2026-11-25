# Plate Layout: nothing runs with its switches off (fix card)
Fix: with the Layout tab's switch (or Nameplate Style, or Enable Style) off, the layout's dirty-list OnUpdate still
woke on every game re-layout of a plate it had touched, and a 1-second ticker of its own ran forever.
Found by: the gating audit's in-game test, /cine debug gating run 1 (Forever, 2026-11-25, step "alloff"): an OnUpdate
loop from Plates/PlateLayout.lua still running
Code: Plates/PlateLayout.lua: Wanted (new), Dirty, the UpdateAnchors hooks, FlushDirty as an ns.FeatureLoop, the
switch check in its wanted() (the ticker gone)
Clients: forever (no layout on retail)
Base: HEAD

## Before / after
- Before: the game laying a plate out again (a target change, a cast's style, plates coming and going) woke the
  layout's loop for every plate it had ever touched, switches on or off; a ticker asked the switches every second.
- After: a plate wakes the layout only while it's the layout's to look after (the layout on, its level box hidden by
  Cinematic, or a preview's copy); the loop is a feature loop with no OnUpdate while nothing waits; the switches are
  asked in the feature loops' shared once-a-second look. Switched off elsewhere, the plates are still put back within
  a second, as before.

## Who relies on the old behavior
- Players: nothing they see changes; less work with the layout off.
- Tests: Tools/offline/platelayout.lua's switch checks (kept) and a new one: the game's re-layouts with the switch off
  leave no loop running and the game's places. The gating test (Dev, the other session's) re-checks it in game.

## States (the matrix)
None: no outcome a player sees changes (the switch's put-back is pinned in Tools/offline/platelayout.lua).

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| none | | | |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a part a hook would have put right with the layout off is left as the game has it, which is what off means.
Not offline: the shared once-a-second look on live plates (the gating test's next run).
