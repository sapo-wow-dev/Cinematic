# Frames: the minimap parked with anchors it can't read (fix card)
Fix: ns.NumPoints gives 0 for an anchor count that's secret (a fight on WoW Forever, another addon's anchors) or
refused; ParkShrunk saved no anchors on that, cleared the map and parked it, and UnparkShrunk then "put back" none:
the minimap off the screen with no anchors till a reload.
Found by: release review 2026-11-22; fixed in ae2cda8 (retroactive card, 2026-11-23)
Code: Frames.lua: ns.ReadNumPoints (new), ns.ParkShrunk (unread or no anchors: left where it is), ns.UnparkShrunk
(none saved: not cleared). Also in ae2cda8, not in this matrix: Style/PersonalMana.lua SetCastPoints/PlaceCastBar
(the cast bar), Style/PersonalStyle.lua, UI/NodeSweep.lua Grow and the sweep's put-back.
Clients: both
Base: ae2cda8^

## Before / after
- Before: a faded minimap whose anchor count read secret or refused as it was parked lost its anchors: once let go
  (or the fade ended) it had none, gone till a /reload. A minimap with no anchors at all was parked too.
- After: unread (or none) as it's parked, it's left where it is, never cleared; let go, it's home.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ReadNumPoints NumPoints UnparkShrunk ParkShrunk`)
- Players: anyone fading the minimap with an addon that lays it out (EllesmereUI, SexyMap) on Forever, or in a fight.
  Nobody wants it lost; the cost of the fix is a faded map left on the screen (arrow pixel when shrunk, the blue
  quest areas when full size) for the fade it couldn't be read in.
- Other features: ShrinkEntry, ParkFullSize, the pass's re-park (ns.ParkUndone, which needs saved anchors), RemoveFrame,
  Diagnostics.lua's sweep Stay(), NodeSweep.lua (its own copy of the guard), Support/EllesmereUI.lua (ns.NumPoints).
- Other addons: EllesmereUI anchors the shrunk map far out itself (IsParkPoint's exact offset).
- Tests that encode it: Tools/offline/minimapfightpark.lua checks 3-4 (kept), fightpoints.lua (ns.NumPoints gives 0).

## States (the matrix)
park (shrunk / fullsize) x anchors (readable / countsecret / countrefused / pointrefused / zero) x when they're
unread (as it's parked / as it's let go) x the pass trying again once they read (retry yes / no), out of a fight,
per client. 40 cells per client.
Test: Tools/offline/unreadanchorsmatrix.lua forever
Test: Tools/offline/unreadanchorsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| unread-anchors | anchors=countsecret when=park | fade=parked end=none later=none | fade=home end=home later=home |
| unread-anchors | anchors=countrefused when=park | fade=parked end=none later=none | fade=home end=home later=home |
| unread-anchors | anchors=zero when=park | fade=parked end=none later=none | fade=none end=none later=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: guards at the top of ParkShrunk and UnparkShrunk. Not proven offline: which of the game's frames really give a
secret count in a fight (fightpoints.lua stands in), the cast bar's move (PlaceCastBar is local, run from timers and
Edit Mode callbacks: not driven here).

## Open
- user's call (FAILs on the current code, unchanged by ae2cda8): unread as it's parked, then readable again, the
  pass never parks it for the rest of that fade (`when=park retry=yes`: fade=home, pinned parked). ParkFullSize has
  set parkedFullSize with no anchors saved, and ns.ParkUndone needs saved anchors, so neither path tries again: the
  faded full-size map's blue quest areas, or the shrunk map's arrow pixel, stay on the screen till it fades again.
- user's call (FAILs on the current and old code): an anchor refused (GetPoint errors) as it's let go
  (`anchors=pointrefused when=letgo`): UnparkShrunk's ns.IsParked reads false, so it's left parked off the screen and
  nothing tries again once it reads (pinned later=home). Unproven that the minimap ever refuses GetPoint in game.
