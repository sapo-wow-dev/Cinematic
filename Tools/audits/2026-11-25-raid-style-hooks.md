# Style: the raid frames' hooks rest while Raid Style and Interface Recolor are off (fix card)
Fix: with Raid Style, Interface Recolor or Enable Style off, every party and raid member's game update (setup, health color, name, update all) still ran our whole restyle
Found by: audit 2026-11-25 (gating, finding D2 in 2026-11-25-gating-findings.md)
Code: Style/RaidStyle.lua: Dress (and its dressed table, new)
Clients: both
Base: baabf86

## Before / after
- Before: Raid Style and Interface Recolor both off (or Enable Style off): in a raid, each member's every
  update ran the full restyle (bar, name, borders, background, recolor), putting back what was never changed.
- After: nothing runs for a frame we never dressed; a frame dressed while a page was on is put back once
  (its first update after the switch, or the page's refresh), then left be. Either page on: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshRaidStyle rfStyle irStyle`)
- Players: none see a change: with both off, Dress only put back what was already the game's.
- Other features: ns.RefreshRaidStyle (the pages' switches, a profile, the roster and fight-end watcher)
  calls the same Dress: switching a page off still puts each dressed frame back at once. The health bar's
  SetValue hook already returned with Raid Style off.
- Other addons: none (frames another addon dressed are its own; we never touched them while off).
- Tests that encode it: followhud PASS, both clients.

## States (the matrix)
Enable Style, Raid Style, Interface Recolor each on or off; the frame fresh or dressed once first; the client.
Test: Tools/offline/raidhooksmatrix.lua forever
Test: Tools/offline/raidhooksmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| raid-style-hooks | general=on raid=off recolor=off before=fresh | restyled=3 | restyled=0 |
| raid-style-hooks | general=off before=fresh | restyled=3 | restyled=0 |
| raid-style-hooks | general=on raid=off recolor=off before=dressed | restyled=3 | restyled=1 |
| raid-style-hooks | general=off before=dressed | restyled=3 | restyled=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the skip only happens with both pages off and the frame not dressed since. A frame Interface Recolor
colored by its own path only (RefreshRaidRecolor's group boxes) is not this Dress: unchanged. Not proven in
game: a raid's frames put back on the page's flip in a fight (Dress waits out fights for borders, as before).
