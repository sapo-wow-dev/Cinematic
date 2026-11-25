# Cameras: Enable Cameras off stops camera scripts too, and the Scripts page off plays ours as shipped (fix card)
Fix: with Enable Cameras off, a scene whose camera is a script of yours still played it, the camera keys and the camera wheel still played scripts, and the camera scripts worked out the scene event every frame; with the Scripts page off a key played your edited copy
Found by: audit 2026-11-25 (gating, findings C14 and D3 in 2026-11-25-gating-findings.md)
Code: Camera/CameraRows.lua: ns.TriggerRowNow; Camera/Camera.lua: ns.ActiveEvent; Camera/CameraScripts.lua: TriggerNow; Core.lua: Cinematic_StartCam
Clients: both
Base: baabf86

## Before / after
- Before: Enable Cameras unticked. The Stand still scene set to a script of yours (or one of your own
  scenes, its camera a script) still plays it as you stand there; the RP walk / auto-run keys and the
  camera wheel still play their scripts. Every frame the camera scripts still work out which scene is on.
  Scripts page off: the walk key still plays the walk script as you edited it.
- After: Enable Cameras unticked, no scene plays (the Scenes page reads off under it: its music and
  CineMode columns too), no key or wheel camera starts (it says "Enable Cameras is off"; one already
  playing still stops on its key), and nothing is worked out but the Skyriding Cam's own script (its own
  switch). Scripts page off: a key plays ours as we ship it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs TriggerRowNow Cinematic_StartCam CameraOffBesidesRows cameraModes`)
- Players: anyone with Enable Cameras off but scenes ticked for their music or CineMode column: those
  scenes stop bringing CineMode on and their music stops, as the Scenes page off already did.
  Enable Cameras is off on a fresh install until a profile is picked (its default).
- Other features: ns.TriggerSetting (music, cine, camera) callers: Atmosphere/Music.lua, Camera.lua's
  CineMode starts, Core.lua's ns.SceneHeldToCine: all read the scene off now. The Skyriding Cam's script
  (TriggerNow's "Skyride") is unchanged: its own switch.
- Other addons: none.
- Tests that encode it: none found reading scenes with Enable Cameras off.

## States (the matrix)
Enable Cameras on/off, the Scenes page on/off, the Scripts page on/off, and what plays: the Stand still
scene's row set to script:u1, or the RP walk key.
Test: Tools/offline/camerasoffmatrix.lua forever
Test: Tools/offline/camerasoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cameras-off-scripts | cameras=off what=scene scenes=on scripts=on | Still script:u1 asked | none not asked |
| cameras-off-scripts | cameras=off what=scene | none asked | none not asked |
| cameras-off-scripts | cameras=off what=key | * | none |
| cameras-off-scripts | cameras=on what=key scripts=off | yours | shipped |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/musicvolume.lua | check 5 "camera music started" and its 6 follow-ons (scene music with Enable Cameras off) | pass | fail (fixed: setup gets cameraModes = true, then passes) | yes, the user 2026-11-25 (picked "4 Camera music") |

## Risk
medium: Enable Cameras off now also silences scenes' music and CineMode columns (the master rule: the
Scenes page off already did). Low otherwise: stopping a playing key camera still works. Not proven
offline: your own scenes' (CustomKeyScene etc.) paths, only the built-in row's; the wheel in game.
