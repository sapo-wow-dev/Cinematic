# Minimap: put back after an anchor refused as it's let go (fix card)
Fix: an anchor read refused (GetPoint errors) as the parked minimap is let go read as "not parked", so its saved
anchors were dropped and it stayed off the screen with nothing trying again.
Found by: audit 2026-11-23 (Tools/audits/2026-11-23-frames-unread-anchors.md, Open)
Code: Frames.lua: ns.UnparkShrunk (an anchor refused: anchors kept, tried again as a fight ends)
Clients: both
Base: 2deb1a9

## Before / after
- Before: let go (shrunk or full size) with GetPoint refused: ns.IsParked's pcall failed and read false, UnparkShrunk
  had already dropped savedPoints, so the minimap stayed parked off the screen till a /reload.
- After: the saved anchors are kept, and as the fight ends (PLAYER_REGEN_ENABLED) it's tried again: home once its
  anchor reads. Skipped then if it was parked again meanwhile (still shrunk or parked full size, not let go).

## Who relies on the old behavior
(`python -I Tools/audit.py refs ParkUndone UnparkShrunk IsParked`, read every hit.)
- Players: nobody wants the map lost off the screen; unproven that the minimap ever refuses GetPoint in game.
- Other features: UnparkShrunk's callers (UnshrinkEntry, UnparkFullSize, RemoveFrame and its fight waiters,
  Diagnostics.lua's sweep Stay). Kept savedPoints means ShrinkEntry, re-shrinking while parked, keeps them (as
  before for a parked map); NodeSweep.lua Grow puts kept ones back (right spot).
- Other addons: none (Support/ has no hit).
- Tests that encode it: unreadanchorsmatrix.lua (pinned later=home, failed before), minimapfightpark.lua check with
  savedPoints = {} (unchanged: returns before the new read), minimapletgomatrix.lua.

## States (the matrix)
park (shrunk / fullsize) x anchors (readable / countsecret / countrefused / pointrefused / zero) x when (park /
letgo) x retry (yes / no), per client.
Test: Tools/offline/unreadanchorsmatrix.lua forever
Test: Tools/offline/unreadanchorsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| unread-anchors | anchors=pointrefused when=letgo | fade=parked end=parked later=parked | fade=parked end=parked later=home |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a pcall'd GetPoint before the IsParked check in UnparkShrunk; only a refused read takes the new branch. Pinned:
the 40 cells per client, the other 36 unchanged. Not proven offline: whether the minimap's GetPoint is ever refused
in game, and a refusal out of a fight waits for the next fight's end (no timer retry).
