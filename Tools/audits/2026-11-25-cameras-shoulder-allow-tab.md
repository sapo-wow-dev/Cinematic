# Shoulder Cam: Allow in flight and while dead follow their tab (fix card)
Fix: Shoulder Cam's Allow on flight paths and Allow while dead were read straight from the saved setting, so with their tab switched off they still allowed it
Found by: audit 2026-11-25 (gating, finding E10 in 2026-11-25-gating-findings.md; decided: a tab off is everything on it off)
Code: Camera/ShoulderCam.lua: PauseReason
Clients: both
Base: baabf86

## Before / after
- Before: the Shoulder Cam page's tab with its Allow boxes (tabOn:Shoulder Cam/page:3) right-clicked
  off: a ticked Allow on flight paths or while dead still kept the shoulder offset on then.
- After: with that tab off, Shoulder Cam pauses on a flight path and while dead, as with the boxes
  unticked. Tab on: the same as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs shoulderCamAllowFlight shoulderCamAllowDeath`)
- Players: only those who ticked these and switched the tab off (both off by default, the tab on).
- Other features: none read these two elsewhere. (The tab's other Allow boxes, read by ALLOW_OF in the
  same function, are left as they were: not part of this finding.)
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
On a flight path or dead, its Allow box ticked or not, the tab on or off.
Test: Tools/offline/shoulderallowmatrix.lua forever
Test: Tools/offline/shoulderallowmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| shoulder-allow-tab | allow=yes tab=off | allowed | paused |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with the tab off and a box ticked. ns.Setting also reads the boxes' masters (Enable Cameras,
Shoulder Cam, Allow outside CineMode), under which Shoulder Cam doesn't run anyway. Not proven
offline: a real flight path or death.
