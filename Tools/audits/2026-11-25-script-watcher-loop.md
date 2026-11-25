# Cameras: the camera scripts' watcher rests with Enable Cameras off (fix card)
Fix: with Enable Cameras off and no script playing, CameraScripts.lua's watcher still worked out the scene every frame
Found by: the gating in-game test, run 1 (testQueue_qd001, Forever, 2026-11-25): CameraScripts.lua:3335 x90 in a step, x120 in "every switch off"
Code: Camera/CameraScripts.lua: the watcher (now ns.FeatureLoop), Start (wakes it)
Clients: both
Base: d6145ed

## Before / after
- Before: Enable Cameras off: the scene-picking watcher ran every frame for nothing (D3's fix made TriggerNow
  answer early, but the loop itself still ran).
- After: no loop at all while Enable Cameras is off and nothing of a script is playing or easing back (its
  zoom, your zoom held, a raised max, its Stop button). On again within a second of Enable Cameras, and at
  once when a script starts (Start wakes it).

- Follow-up (run 4, 2026-11-25): a scene you stopped (stoppedFor) no longer keeps the loop wanted with
  Enable Cameras off: its 2 s clear-out (zoomer.OFF_CLEAR) waits till cameras are on again, when nothing
  could have started meanwhile anyway. Run 4 saw the loop run 24 frames on that clear-out.

## Who relies on the old behavior
(`python -I Tools/audit.py refs zoomer.TriggerNowSeen PlayCameraScript`)
- Players: none; with Enable Cameras on (the default) the loop runs every frame as before.
- Other features: a script started by hand (the wheel, a key, the Scripts page's Play) with Enable Cameras
  off: Start wakes the loop, which then runs while it plays and eases back.
- Tests that encode it: scriptreplace, scriptreplacematrix, camerasoffmatrix (cameras on: unchanged).

## States (the matrix)
Enable Cameras on or off, a script playing or nothing; the client.
Test: Tools/offline/scriptwatchermatrix.lua forever
Test: Tools/offline/scriptwatchermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| script-watcher-loop | cameras=off script=none | loop on | loop off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: wanted() is true whenever Enable Cameras is on or a script has anything left; the loop's body is
unchanged. Not proven offline: a real scene starting within a second of Enable Cameras going back on.
