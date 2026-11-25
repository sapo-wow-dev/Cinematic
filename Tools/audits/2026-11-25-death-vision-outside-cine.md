# Death Vision: its own Allow outside CineMode tick, as every other Vision (fix card)
Fix: Death Vision had no Allow outside CineMode tick: its row on the CineMode page couldn't be set to CineMode only
Found by: audit 2026-11-25 (gating, your-call item E11); asked for by the user ("fix Death Vision has no Allow outside CineMode tick")
Code: Core.lua: OUTSIDE_CINE (deathScreen -> outsideCineDeath, on by default); Options.lua: the CineMode page's OUTSIDE list; Atmosphere/DeathVision.lua: its screen's two reads through ns.Setting
Clients: both
Base: 39fdb5d

## Before / after
- Before: the CineMode page's Death Vision row had no Always / CineMode choice; Death Vision showed wherever
  the death camera ran (held back outside CineMode only by the Cameras' own tick).
- After: its row has the choice like Heal, Damage, Vitals, Quest, Roll, Teleport, Duel, Emote and Card Vision.
  On by default (Always), so nothing changes for anyone until they pick CineMode.

## Who relies on the old behavior
(`python -I Tools/audit.py refs deathScreen outsideCineDeath`)
- Players: none; the tick defaults on, as every OUTSIDE_CINE tick (Core.lua sets them all true).
- Other features: the death camera (Camera.lua DeathCinematicWanted) still decides when it runs; Death Vision
  rides on it as before. Its Test button shows whatever the tick says, as the other Visions' tests do.
- Tests that encode it: none read the tick; sweep and gate checks run below.

## States (the matrix)
The tick on or off, CineMode on or off (Death Vision's page on); the client.
Test: Tools/offline/deathoutsidematrix.lua forever
Test: Tools/offline/deathoutsidematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| death-vision-outside-cine | tick=off cine=off | may show | held |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a new tick, on by default; with it off, Death Vision only in CineMode. Not proven in game: a death with
the tick off and CineMode off (needs a death).
