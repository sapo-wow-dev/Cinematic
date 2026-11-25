# Quality of Life: with Cameras left out, the Fishing page and the login zoom row are hidden (fix card)
Fix: with Load Cameras unticked, the Fishing page and Quality of Life's "Reset the zoom on login and /reload" row still showed but did nothing (their code is the Cameras part's)
Found by: audit 2026-11-25 (gating, finding E9 in 2026-11-25-gating-findings.md; decided: hide what can't be used)
Code: Options.lua: CreateQualityPanel (the login zoom rows), the panels' build (CreateFishingPanel)
Clients: both
Base: baabf86

## Before / after
- Before: Cameras left out: the Quality of Life hub still has a Fishing icon, its page's switches do
  nothing; QoL General still has Reset the zoom on login and its Zoom to slider, which do nothing.
- After: neither is made with Cameras left out, as the hub already does for pages that aren't made
  (the Hunter page on retail). Loaded: the same as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CreateFishingPanel loginZoom handleFishing`)
- Players: those with Cameras left out lose two controls that did nothing. Saved values are kept.
- Other features: the Fishing page's profile slot (Profiles/ProfileModules.lua handleFishing) and the
  Why window's "Fishing" name only read settings. Searching settings for them finds nothing then.
- Other addons: none.
- Tests that encode it: partrowsmatrix.lua (cameras out: every row repaints): fewer rows, no change.

## States (the matrix)
Cameras loaded or left out (a fresh load each).
Test: Tools/offline/camerapagesoutmatrix.lua forever
Test: Tools/offline/camerapagesoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cameras-out-pages | loaded=out | fishing page yes, login zoom row yes | fishing page no, login zoom row no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with Cameras left out. Not proven offline: the hub's Fishing icon gone in game (the hub skips
pages that weren't made, as for Hunter on retail).
