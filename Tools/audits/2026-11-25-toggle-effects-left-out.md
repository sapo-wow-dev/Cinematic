# Atmosphere: the Toggle visual effects key with Atmosphere left out (fix card)
Fix: with Atmosphere not loaded, the Toggle visual effects key still flipped Enable Visual Effects and said "visual effects on/off", though nothing could show
Found by: audit 2026-11-25 (gating, the lead's list: Effects.lua Cinematic_ToggleVisualEffects)
Code: Effects.lua: Cinematic_ToggleVisualEffects
Clients: both
Base: baabf86

## Before / after
- Before: Load Atmosphere unticked (after the reload), the key: "visual effects on" (or off) and the saved
  switch flipped, with nothing on screen.
- After: it says "Atmosphere isn't loaded (Atmosphere > General > Load Atmosphere)", as the letterbox key
  does, and changes nothing. Loaded: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs Cinematic_ToggleVisualEffects`)
- Players: none want a switch flipped that does nothing.
- Other features: Bindings.xml calls the global, which is always there (Effects.lua is core), so Modules.lua's
  KEY_STAND_INS, which only fills a missing global, can't stand in: the check is in the function.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
Atmosphere loaded or left out, Enable Visual Effects on or off; the client. One load per cell.
Test: Tools/offline/togglefxmatrix.lua forever
Test: Tools/offline/togglefxmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| toggle-effects-key | atmosphere=out effects=on | said=off flipped | said=notLoaded kept |
| toggle-effects-key | atmosphere=out effects=off | said=on flipped | said=notLoaded kept |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one check, true whenever Atmosphere is loaded. Not proven in game: the key with Atmosphere left out.
