# Vitals Vision: low mana's checks run only while it can show (fix card)
Fix: Mana Vision's check loop ran every frame for every player (the Mana tab off by default, characters with no mana, any state), and every power tick (energy, rage too) repainted the overlay
Found by: release review 2026-11-23 (f82b83f)
Code: Atmosphere/ManaVision.lua: the driver (ns.SetOnUpdate -> ns.FeatureLoop with a gate), the events handler (UNIT_POWER_UPDATE for MANA only; other events wake the gate), Paint (skips when nothing of the look changed), ns.RefreshManaVision (repaints, wakes the gate)
Clients: both
Base: HEAD

## Before / after
- Before: a frame's update ran every frame from login for everyone, calling Update every 0.25 s; every UNIT_POWER_UPDATE (energy, rage, runic power: several a second) ran Update, and with the Mana tab on each Update repainted the veil and every edge piece.
- After: the loop runs only while it can show: the page's Test running, or the Mana tab on (ns.Setting: its page, CineMode or Allow outside CineMode) for a character with mana, or the overlay still up and to be hidden. On at once from the page (Refresh wakes it), a /cine debug test, a form or spec giving mana (UNIT_DISPLAYPOWER / UNIT_MAXPOWER wake it), login with it on; else within the second (Diagnostics' ns.SyncFeatureLoops). Only MANA ticks (or a secret / missing power type) check again. The veil and edges are painted only when the look, strength, reach or screen size changed, or on Refresh. What shows doesn't change.

## Who relies on the old behavior
- Players: none see a change (nothing showed in the states the loop now stops in).
- Other features: LowHealth.lua's refresh calls ns.RefreshManaVision (now also repaints and wakes the gate). The pages' Test buttons and preview have their own loops (unchanged).
- Other addons: none.
- Tests that encode it: Tools/offline/manavision.lua (92 checks, all kept; 24 new loop/tick/paint/login checks added), Dev/ManaVisionTest.lua (waits for UNIT_POWER_UPDATE itself: unaffected).

## States (the matrix)
The Mana tab's setting on/off, the Vitals Vision page on/off, has mana / none, the Test running or not, CineMode on/off, Allow outside CineMode on/off; the client.
Test: Tools/offline/manavisionloopmatrix.lua forever
Test: Tools/offline/manavisionloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| manavision-loop | setting=off test=no | loop=yes shown=no | loop=no shown=no |
| manavision-loop | setting=on page=off test=no | loop=yes shown=no | loop=no shown=no |
| manavision-loop | setting=on page=on mana=none test=no | loop=yes shown=no | loop=no shown=no |
| manavision-loop | setting=on page=on mana=has test=no cine=off outside=off | loop=yes shown=no | loop=no shown=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: nothing drawn changes. A switch flipped without a page refresh (a profile load, the Allow outside tick, CineMode coming on with the tick off) starts it within a second. Not proven offline: the real game's UNIT_DISPLAYPOWER on a druid form change (stubbed by firing it), the curve path on Forever with secret mana while the loop starts and stops, and that a Show in row turning on later is still caught (the loop runs whenever the tab's on for a mana user, so it is).
