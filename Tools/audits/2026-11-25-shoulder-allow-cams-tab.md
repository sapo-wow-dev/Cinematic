# Shoulder Cam: every Allow box follows its tab, not only flight and death (fix card)
Fix: Shoulder Cam's Allow boxes for Cinematic's cameras (vista, fish, cozy, AFK, teleport, fly-by, death camera, your own, walk, auto-run, quest, Chat Cam) were read straight from the saved setting, so with their tab switched off a ticked box still allowed it; only the flight path and death pauses followed the tab
Found by: audit 2026-11-25 (review of the 2026-11-25-cameras-shoulder-allow-tab.md fix, which left these out as not part of finding E10)
Code: Camera/ShoulderCam.lua: PauseReason
Clients: both
Base: cc7e40d

## Before / after
- Before: the Shoulder Cam page's tab with its Allow boxes (tabOn:Shoulder Cam/page:3) right-clicked
  off: Shoulder Cam paused on a flight path and while dead, but a ticked Allow box for one of
  Cinematic's cameras (Walk and Auto-run are ticked by default) still kept the shoulder offset on while
  that camera ran.
- After: with that tab off, every camera on it pauses Shoulder Cam, as with its box unticked (the
  decided rule: a tab off is everything on it off). Tab on: the same as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs shoulderCamAllowWalk ALLOW_OF PauseReason`, every hit read.)
- Players: only those who switched that tab off; Walk and Auto-run are on by default, so for them the
  walk and auto-run cameras now pause Shoulder Cam with the tab off.
- Other features: none read these boxes elsewhere; ns.Setting also reads their masters (Enable Cameras,
  Shoulder Cam, Allow outside CineMode), under which Shoulder Cam doesn't run anyway.
- Other addons: none.
- Tests that encode it: Tools/offline/shoulderallowmatrix.lua (flight path / death: unchanged);
  Tools/shoulder-sim/sim.lua sets the boxes with the tab on its default (on: unchanged).
  Dev/ShoulderCamTest.lua:7060 (the fake-self step) ticks every box to keep Shoulder Cam on through the
  event cameras but doesn't turn the tab on: with the tester's tab off, that step would now pause (not
  changed here; the test skill's call).

## States (the matrix)
Which camera runs (8 event cameras, 4 playing ones), its Allow box ticked or not, the tab on or off; the client.
Test: Tools/offline/shoulderallowcamsmatrix.lua forever
Test: Tools/offline/shoulderallowcamsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| shoulder-allow-cams-tab | allow=yes tab=off | allowed | paused |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with the tab off and a box ticked (Walk / Auto-run ticked by default). Not proven offline: a
real camera running (ns.ActiveEvent and ns.activeCam are stand-ins in the matrix).
