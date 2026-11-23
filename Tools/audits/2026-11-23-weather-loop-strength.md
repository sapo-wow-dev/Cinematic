# Weather: the effects' loop runs only when one can draw (fix card)
Fix: frost, rain on the lens, lightning and heavier weather ran their update every frame in any rain or snow in CineMode at their default strength Off, with their switch or the Weather page off too
Found by: release review 2026-11-23
Code: Atmosphere/WeatherFX.lua: Wanted (now asks Strength per effect); Core.lua: the effect pass's page switch (EFFECT_PAGE: weatherPage for the four)
Clients: both
Base: HEAD

## Before / after
- Before: the loop ran while any of the four effects' Show in row said yes (rule "weather": any rain, snow or sandstorm), drawing nothing at strength 0 or with the page off; the Why window and /cine debug called them wanted with the Weather page off.
- After: the loop runs only while one can draw (its row, strength up, its switch, the page and Visual Effects on), or a preview, a fade still going, a flash or the held density. Nothing on screen changes; the effect pass reads the Weather page's switch for the four.

## Who relies on the old behavior
- Players: none see a change (nothing drew in those states); a little less work per frame in rain.
- Other features: Strength() already gated what draws; the density hold is let go by its own branch (densitySet.active keeps the loop for that pass). Why / debug read ns.effectWanted.
- Other addons: none.
- Tests that encode it: Tools/offline/atmopreview.lua (33 pass), loopsoff.lua (ALL PASS).

## States (the matrix)
The effect (4), its row yes/no, its strength off/up, its switch on/off, the Weather page on/off; the client.
Test: Tools/offline/weatherloopmatrix.lua forever
Test: Tools/offline/weatherloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| weatherfx-loop | row=yes strength=off | loop=on | loop=off |
| weatherfx-loop | row=yes strength=up switch=off | loop=on | loop=off |
| weatherfx-loop | row=yes strength=up switch=on page=off | loop=on | loop=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: nothing drawn changes. A strength raised mid-rain starts the loop within a second (Diagnostics' once-a-second ns.SyncFeatureLoops asks Wanted again). Not proven offline: the Why window's lines with the page off (the effect pass runs in game only).
