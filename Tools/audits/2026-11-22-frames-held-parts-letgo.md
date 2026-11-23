# Frames: a unit frame part held by a Hover group, its frame let go (fix card)
Fix: a Hover group with a part unticked (the portrait) holds that part hidden while the group alone has the frame
up; only the pass over managed frames let go of the hold, so a frame let go meanwhile kept the part hidden till a reload.
Found by: audit 2026-11-22; fixed in 7c3e0c1 (retroactive card, 2026-11-23)
Code: Frames.lua: RemoveFrame() (ns.HoldUnitParts(name, false, false) as the entry goes), ns.HoldUnitParts
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: the player frame up for a Hover group with Portrait unticked, then let go (its fade switch off, a
  profile, /cine keep): the portrait stayed hidden till a /reload.
- After: let go, the portrait is as its own Standard Frames row says: shown when ticked, hidden when not.

## Who relies on the old behavior
(`python -I Tools/audit.py refs HoldUnitParts FRAMES.held`)
- Players: Hover groups with unticked parts (Auto-Hide UI); nobody wants a part hidden on a frame Cinematic no
  longer fades.
- Other features: UpdateFrames' per-entry HoldUnitParts (Frames.lua 13310, the normal path), ApplyUnitFrameParts and
  the theme art hold (FRAMES.themeHeld), FRAMES.Reveal. RemoveFrame runs HoldUnitParts for every frame let go (a
  no-op for frames with no hold).
- Other addons: none (Support/ has no hit).
- Tests that encode it: Tools/offline/heldpartsletgo.lua check 1 (it sets the hold with a lowercase "portrait",
  which no part is named, so it checks the held table only, not that the portrait shows: this matrix does).

## States (the matrix)
the group (holds the Portrait / none) x the portrait's own row (on / off) x the frame (up / fading out) x let go
(yes / no), HUD page on, per client. 16 cells per client.
Test: Tools/offline/heldpartsmatrix.lua forever
Test: Tools/offline/heldpartsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| unitparts-letgo | group=holds row=on letgo=yes | hidden | shown |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: one call as the entry goes; no other cell changes (audit.py card --new 7c3e0c1). Not proven offline: a part
with a rule (FRAMES.ruled) fades back in over the fade time instead of at once; the theme ring (UnitThemeArt).
