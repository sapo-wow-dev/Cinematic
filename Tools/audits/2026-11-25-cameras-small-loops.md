# Cameras: the zoom guard, the Skyriding Cam's watch and the campfire buff scan run only when needed (fix card)
Fix: three small Cameras watches ran for everyone, always: the zoom guard every frame, the Skyriding Cam's watch every frame (retail), and a campfire buff scan on every aura change of yours with Enable Cameras or the Scenes page off
Found by: audit 2026-11-25 (gating, finding D15, the Cameras ones, in 2026-11-25-gating-findings.md)
Code: Camera/ZoomGuard.lua: NoteOurs, Watch, its frame (a FeatureLoop now); Camera/SkyrideCam.lua: its watcher (a FeatureLoop now); Camera/CameraScripts.lua: ns.SkyridingNow (wakes it); Camera/Camera.lua: CheckIdleBuffs
Clients: both (the Skyriding Cam: retail)
Base: baabf86

## Before / after
- Before: the zoom guard read the camera distance every frame whether or not one of our zooms ran;
  the Skyriding Cam's watch ran every frame on the ground too; every aura change of yours scanned for
  the campfire buffs with no scene able to use them.
- After: the zoom guard runs from one of our zooms until 30 s after the last (its trace's length),
  woken by the zoom itself; the Skyriding Cam's watch from the moment you're skyriding with its page on
  (ns.SkyridingNow, asked every frame by the camera scripts, wakes it) until its flight is put away;
  the campfire scan only with the Scenes page on (Enable Cameras above it). Their work while on: the same.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ZoomTraceDump zoomGuard SkyridingNow CheckIdleBuffs campfireBuff`)
- Players: none see a difference. `/cine debug zoomtrace` shows nothing older than our last zooms
  (the trace starts afresh after 30 s with none); the guard's "swung, not ours" log line needs one of
  our zooms in the last 30 s now.
- Other features: the Campfire scene and triggers naming Campfire (atCampfire): no scene plays with
  the Scenes page off. Switched back on at a fire, the buff is seen at the next aura change or
  loading screen. The Skyriding sim (Tools/skyride-sim/sim.lua page, plain, swing, mouse): its output
  is byte for byte the same as on the base.
- Other addons: none.
- Tests that encode it: none found (modules.lua: none of these with Cameras left out, unchanged).

## States (the matrix)
Each watch wanted or not: one of our zooms lately or not; the Skyriding Cam page on or off, in the
air or on the ground; Enable Cameras on or off for the buff scan.
Test: Tools/offline/cameraloopsmatrix.lua forever
Test: Tools/offline/cameraloopsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| camera-small-loops | watch=zoomguard on=no | loop on | loop off |
| camera-skyride-loop | page=off | loop on | loop off |
| camera-skyride-loop | page=on skyriding=ground | loop on | loop off |
| camera-small-loops | watch=campfire on=no | buff seen | not looked |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: each is on whenever it was doing anything. Not proven offline: the zoom guard tripping on a real
zoom fight (it wakes on the first zoom, the swing count from there), a real skyriding take-off.
