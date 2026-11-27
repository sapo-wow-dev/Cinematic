# Plate Layout: a saved layout comes back with its switch (fix card)
Fix: with a layout saved but Enable Style, Nameplate Style or the Layout tab's switch off as the first plate came,
turning the switch on did nothing till a loading screen, a /reload or a change on the Layout page.
Found by: audit 2026-11-25
Code: Plates/PlateLayout.lua: the driver's feature-loop wanted() (the switch look, now with no plate hooked too),
HookLayout (anyHooked gone)
Clients: forever (no layout on retail)
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: Active() cached "off" at the first plate with a switch off, nothing was hooked, and the once-a-second
  switch look only ran while a plate was hooked: switching on left the plates as the game has them until a loading
  screen, /reload or a Layout page change.
- After: the once-a-second look always asks the switches; a flip on lays the saved layout on every plate within a
  second, a flip off puts them back, as before. Nothing more runs while nothing changes (two switch reads a second,
  in the feature loops' shared look; no OnUpdate).

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateLayoutChanged PlateLayoutActive anyHooked`, read every hit.)
- Players: those with a layout saved and a switch off at login now get it the moment they turn the switch on, which
  is what the switch says.
- Other features: ns.PlateLayoutChanged's callers (the Layout page, profiles) unchanged; it is now also called on a
  flip with nothing hooked (one pass over the plates per flip).
- Other addons: none.
- Tests that encode it: Tools/offline/platelayout.lua (switch off puts back, no loop with the switch off: kept),
  Tools/audits/2026-11-25-plate-layout-gating.md (nothing runs with the switches off: kept, the look is the shared
  once-a-second one, no OnUpdate, pinned "quiet" here).

## States (the matrix)
Which switch (Enable Style, Nameplate Style, Layout), turned on (off at the first plate) or off (on at it), a layout
saved or none. Each cell: the level box at the start and after the flip, and whether the next look with nothing
changed is quiet (no new pass, no loop on).
Test: Tools/offline/platelayoutswitchmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-switch | flip=turnOn saved=layout | start=game now=game quiet | start=game now=moved quiet |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a flip with nothing hooked now walks the plates once (GetNamePlates, Active() asked per plate). Not offline:
the real StyleOn chain (MasterOff, another addon's Theirs yielding a switch: read the same way by SwitchOn) and
live plates in game (the in-game run: layout saved, Nameplate Style off, /reload, turn it on, plates move within a
second).
