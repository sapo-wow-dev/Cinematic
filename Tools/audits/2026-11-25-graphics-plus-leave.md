# Atmosphere: Graphics+ stays put back once Load Atmosphere is unticked (fix card)
Fix: unticking Load Atmosphere and picking Later put Graphics+ back, but the next fight's end wrote it again, and after the reload it stayed raised for good
Found by: audit 2026-11-25 (gating, finding B1 in 2026-11-25-gating-findings.md)
Code: Graphics.lua: ns.ApplyGraphicsPlus
Clients: both
Base: badf2f0

## Before / after
- Before: Graphics Boost on (Terrain detail raised, say). Untick Load Atmosphere, pick Later on the reload
  box: the game's own values come back. The next fight ends (or any page or profile applies the settings):
  Graphics+ writes its values again. Reload: Atmosphere isn't loaded, so nothing puts them back, and the
  game keeps them (it saves graphics settings) for as long as Atmosphere stays out.
- After: once unticked, Graphics+ only puts back, never writes, till the reload. Ticked again before the
  reload, it writes again.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ApplyGraphicsPlus GraphicsPlusPutBack`)
- Players: none want the boost kept with Atmosphere left out (the Load box's own words: leaving it out
  puts the game's values back).
- Other features: callers of ns.ApplyGraphicsPlus (the Graphics Boost page and tabs, Visual Effects
  switch, toggle key, Reset page, its fight-end/login/CVar watcher): all now put back while unticked.
- Other addons: none.
- Tests that encode it: Tools/offline/modules.lua (atmosphere left out: no Graphics+ code at all), the
  Graphics+ offline checks: unchanged (the part is wanted in them).

## States (the matrix)
Load Atmosphere kept or unticked (Later), Graphics Boost's page on or off, then a fight ending or the
settings applied again; the client.
Test: Tools/offline/graphicsleavematrix.lua forever
Test: Tools/offline/graphicsleavematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| graphicsplus-leave | load=unticked page=on | ours | game |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more condition on the wanted value, true whenever Load Atmosphere is ticked (every player but
those who just unticked it). Not proven in game: the fight's end before the reload with the game's real
graphics settings.
