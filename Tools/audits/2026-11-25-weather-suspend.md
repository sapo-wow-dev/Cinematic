# Weather: frost, lens rain and lightning stop with a safety stop (fix card)
Fix: after a safety stop or /cine stop mid-weather, frost, rain on the lens and lightning kept drawing and thundering, and Heavier weather held the game's weather density again
Found by: audit 2026-11-25 (gating, finding C16 in 2026-11-25-gating-findings.md)
Code: Atmosphere/WeatherFX.lua: Strength; Core.lua: RestoreEverything, ns.Resume
Clients: both
Base: baabf86

## Before / after
- Before: Cinematic stopped for the session (a repeating error, /cine stop) while frost, lens rain, a storm
  or Heavier weather was on: the letterbox, tint and haze went, but the weather's frame kept drawing, its
  lightning flashing and thundering, and the next frame held weatherDensity again after the stop let it go.
- After: stopped, the weather's frame is hidden at once (as the tint and haze are) and none of its effects
  is wanted, so nothing draws, thunders or holds the density. /cine resume shows it again and the effects
  come back as their rows say.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CinematicWeatherFX RestoreEverything`)
- Players: nobody wants effects after a stop that says it put their UI and settings back.
- Other features: the Weather page's previews (none while stopped now; back after resume), /cine debug
  atmosphere (reads the drawn levels).
- Other addons: none.
- Tests that encode it: weatherloopmatrix.lua (not stopped): unchanged.

## States (the matrix)
Each of the four effects, Cinematic carrying on or stopped (ns.Suspend); the client.
Test: Tools/offline/weathersuspendmatrix.lua forever
Test: Tools/offline/weathersuspendmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| weatherfx-suspend | stop=suspended | shows | gone |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only after a stop. Touches ns.Resume too (one Show line, beside the haze's). Not proven in game: the
frame coming back on /cine resume mid-rain.
