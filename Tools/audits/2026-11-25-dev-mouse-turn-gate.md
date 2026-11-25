# Dev tools: Mouse Turn goes with the Cameras part and its tab (fix card)
Fix: the dev copy's Mouse Turn cap sat outside the Cameras part and ignored its Camera Settings tab, so it still slowed the mouse look speed with Cameras left out or its tab off
Found by: audit 2026-11-25 (gating, finding C18 in 2026-11-25-gating-findings.md)
Code: Dev/MouseTurn.lua: the whole file in ns.Module("cameras"); On, Apply, Update
Clients: both (dev copy only)
Base: baabf86

## Before / after
- Before: Cap ticked: with Load Cameras unticked (after the reload), or its Mouse Turn tab on the
  Camera Settings page right-clicked off, turning with the right mouse button still had its speed held
  down (the game's Mouse Look Speed written).
- After: it runs only with Cameras loaded, Enable Cameras on, its tab on and the cap or ramp ticked;
  with Cameras left out its code doesn't load at all (and its tab's section isn't built, as Options.lua
  makes it only when ns.mouseTurnState is there).

## Who relies on the old behavior
(`python -I Tools/audit.py refs mouseTurnCap mouseTurnState`)
- Players: none (dev copy only).
- Other features: Options.lua's Mouse Turn section (built only with ns.mouseTurnState).
- Other addons: none.
- Tests that encode it: modules.lua and /cine debug loadparts: Dev/MouseTurn.lua counts as a Cameras
  file now (ns.Module records it).

## States (the matrix)
Cameras loaded or left out, Enable Cameras on or off, its tab on or off, the cap ticked or not.
Test: Tools/offline/mouseturnmatrix.lua forever
Test: Tools/offline/mouseturnmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| mouse-turn-gate | loaded=in cameras=on tab=off cap=on | loop on | loop off |
| mouse-turn-gate | loaded=out cameras=on cap=on | loop on | loop off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: dev copy only. Not proven offline: the tab's right-click in game putting your speed back at once
(its loop's wanted() releases it on the next 1 s sync).
