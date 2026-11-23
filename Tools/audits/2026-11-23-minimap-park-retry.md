# Minimap: parked once its anchors read again (fix card)
Fix: a faded minimap whose anchors couldn't be read as it was parked (count secret or refused, an anchor refused) was
left on the screen, and once they read again nothing parked it for the rest of that fade: the shrunk map's arrow
pixel, or the full-size map's blue quest areas, stayed on the screen.
Found by: audit 2026-11-23 (Tools/audits/2026-11-23-frames-unread-anchors.md, Open)
Code: Frames.lua: ns.ParkUndone (no anchors saved: undone while it isn't parked)
Clients: both
Base: 2deb1a9

## Before / after
- Before: unread as it's parked, then readable again: left on its own spot till it faded again (ParkFullSize had set
  parkedFullSize with no anchors saved, ParkShrunk had saved none, and ns.ParkUndone needs saved anchors, so neither
  the shrunk pass nor ParkFullSize tried again).
- After: the next pass (shrunk) or ParkFullSize call (full size, quest area on it) parks it once its anchors read.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ParkUndone UnparkShrunk IsParked`, read every hit.)
- Players: anyone fading the minimap whose anchors read secret or refused as it parks (another addon's layout, a
  fight on WoW Forever). Nobody wants the arrow pixel or quest areas left showing.
- Other features: ns.ParkUndone's callers are only ParkFullSize and SetEntryAlpha's shrunk re-park branch; both only
  run while shrunk or parkedFullSize. With no anchors saved, ParkShrunk is now tried each pass: while still unread it
  returns at its own guards (one pcall'd count read a pass), never clearing.
- Other addons: EllesmereUI lays the map out again (ParkUndone's existing case, saved anchors: unchanged).
- Tests that encode it: unreadanchorsmatrix.lua (pinned parked, failed before), minimapfightpark.lua.

## States (the matrix)
park (shrunk / fullsize) x anchors (readable / countsecret / countrefused / pointrefused / zero) x when (park /
letgo) x retry (yes / no), per client.
Test: Tools/offline/unreadanchorsmatrix.lua forever
Test: Tools/offline/unreadanchorsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| unread-anchors | anchors=countsecret when=park retry=yes | fade=home end=home later=home | fade=parked end=home later=home |
| unread-anchors | anchors=countrefused when=park retry=yes | fade=home end=home later=home | fade=parked end=home later=home |
| unread-anchors | anchors=pointrefused when=park retry=yes | fade=home end=home later=home | fade=parked end=home later=home |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one early return in ns.ParkUndone, only reached while shrunk or parked full size with no anchors saved; the
40 cells per client pinned, the other 34 unchanged, both clients. Not proven offline: which frames really give an
unread count as the minimap parks in game, and the per-pass cost of trying again while they stay unread (one
pcall'd GetNumPoints, or a GetPoint for a refused anchor).
