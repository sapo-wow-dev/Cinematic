# Cameras: the raised max zoom stays up while any camera holds it (fix card)
Fix: the idle zoom (and the quest cam taking it over) and camera scripts' Past max share one raised max zoom (2.6); either letting go put yours back, snapping the other's camera in while it was still out past your max.
Found by: audit 2026-11-22 (retroactive card 2026-11-23)
Code: Camera/Camera.lua: RaiseZoomMax(who), ZOOM_MAX_CVARS.LetGo, ns.RaiseZoomMax/LowerZoomMax, ns.RestoreZoomLimit, StopIdleZoomNow, FinishRestore, UpdateIdleZoom, UpdateTaxi
Clients: both
Base: bdb2e1d^

## Before / after
- Before: a camera script zoomed out past your max while the idle zoom (or a quest cam) also had it raised: the
  first to finish put your max back, and the other's camera snapped in.
- After: the max stays raised until both have let go; a safety stop or logout still puts yours back at once; a max
  of yours already past 2.6 (Graphics+) is never touched.

## Who relies on the old behavior
(`python -I Tools/audit.py refs LowerZoomMax RestoreZoomLimit ZoomMaxHolds`)
- Players: idle zoom / quest cam / Past max script users; Graphics+ max past 2.6.
- Other features: Camera/QuestCam.lua (RestoreZoomLimit x4, TakeOverZoom), Camera/CameraScripts.lua (Finish,
  maxHeldTo), Core.lua RestoreEverything (StopIdleZoomNow, and now the cvarSets loop).
- Tests that encode it: Tools/offline/fightsfades.lua check 2.

## States (the matrix)
your max (1.9 / 3.0 Graphics+) x who raised it (idle / script / idle then script / script then idle) x who lets go
first (the idle side: RestoreZoomLimit / the script: LowerZoomMax / a stop: StopIdleZoomNow), then the rest, per client.
Test: Tools/offline/zoommaxmatrix.lua forever
Test: Tools/offline/zoommaxmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| zoom-max | yours=1.9 raised=idle first=script | first=yours end=yours | first=raised end=yours |
| zoom-max | yours=1.9 raised=script first=idle | first=yours end=yours | first=raised end=yours |
| zoom-max | yours=1.9 raised=idle+script first=idle | first=yours end=yours | first=raised end=yours |
| zoom-max | yours=1.9 raised=idle+script first=script | first=yours end=yours | first=raised end=yours |
| zoom-max | yours=1.9 raised=script+idle first=idle | first=yours end=yours | first=raised end=yours |
| zoom-max | yours=1.9 raised=script+idle first=script | first=yours end=yours | first=raised end=yours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: 6 of 24 cells per client changed, exactly the "other still holds it" ones; stops and Graphics+ unchanged. Not
proven offline: the real idle zoom raising it (the matrix calls Camera.lua's local RaiseZoomMax as StartIdleZoom
does), the camera's real distance (limitHeldTo, maxHeldTo), a let-go by a holder that never raised it.

## Open
- raised=idle first=script: a script never lowers it without having raised it (Finish checks run.raisedMax), so this
  cell can't happen in play; pinned raised (the idle zoom still holds it).
