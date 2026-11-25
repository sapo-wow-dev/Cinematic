# Diagnostics: a loop its breaker turns off puts away what it drew, and /cine resume brings it back (fix card)
Fix: a protected update loop that kept failing was turned off with whatever it drew left on screen, frozen (Teleport
Vision's portal, Vitals' edges, the campfire button, the emote card, the camera wheel...), and only a reload or
switching the feature off and on brought it back. /cine resume didn't.
Found by: overlay audit 2026-11-25 (player case: Teleport Vision stuck on screen till Alt+F4)
Code: Diagnostics.lua: Protect (state.clear run as it trips), ns.SetOnUpdate / ns.FeatureLoop (clear argument),
ns.ReviveLoops (new); Core.lua: ns.Resume calls it. Clears passed by: Atmosphere/TeleportVision.lua (portal, cast
bar fade), Focus.lua, ManaVision.lua, WeatherFX.lua, LowHealth.lua (Vitals driver, shaker), QoL/Campfire.lua,
Visions/SleepingBag.lua, Visions/EmoteVision.lua (card), Visions/DamageVision.lua (display), Camera/CameraWheel.lua
Clients: both
Base: cb97e07

## Before / after
- Before: one of these features hitting an error every frame stopped where it was: a portal, red edges, a haze, frost,
  the campfire button or emote card (still catching clicks), the camera wheel over the whole screen, frozen till a
  reload. Your tooltips and cast bar stayed faded with a teleport's; the game's own low-health flash stayed hidden.
- After: as the loop is turned off, the feature puts away what it shows and resets, the same way its own "off"
  does. /cine resume starts every turned-off loop again (off again after 5 more errors if still failing).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SetOnUpdate FeatureLoop Breaker`)
- Players: nobody wants a frozen overlay. A loop that keeps failing still stays off while left alone: no error stream.
- Other features: every ns.FeatureLoop / ns.SetOnUpdate caller; the clear argument is optional, so the rest are
  unchanged. A wake (ns.WakeFeatureLoop) does NOT revive a dead loop: features wake theirs on many events.
- Other addons: none.
- Tests that encode it: Tools/offline/featureloopmatrix.lua (card 2026-11-22-diagnostics-feature-loop-restart.md):
  its cells unchanged (no clear passed there; stayon still runs=0).

## States (the matrix)
dead-loop-clear: the loop (every frame / 1 s timer / a set loop) x then (left on / /cine resume / off and on, or set
again) x what it runs (fixed / still failing). dead-loop-teleport: Teleport Vision's test with its loop failing, then
left on or resumed.
Test: Tools/offline/deadloopmatrix.lua forever
Test: Tools/offline/deadloopmatrix.lua retail
Test: Tools/offline/featureloopmatrix.lua forever
Test: Tools/offline/featureloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| dead-loop-clear | then=stayon | cleared=0 runs=0 | cleared=1 runs=0 |
| dead-loop-clear | then=resume fixed=yes | cleared=0 runs=0 | cleared=1 runs=8 |
| dead-loop-clear | then=resume fixed=no | cleared=0 runs=0 | cleared=2 runs=5 |
| dead-loop-clear | then=offon fixed=yes | cleared=0 runs=8 | cleared=1 runs=8 |
| dead-loop-clear | then=offon fixed=no | cleared=0 runs=5 | cleared=2 runs=5 |
| dead-loop-teleport | then=stayon | tripped=shown after=shown | tripped=hidden after=hidden |
| dead-loop-teleport | then=resume | tripped=shown after=shown | tripped=hidden after=shown |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the clears run only as a breaker trips (5 errors in 3 s), and the revive only on /cine resume. Proven offline
for the machinery and Teleport Vision; the other features' clears were read, not run (no offline way to trip them
each). Not proven in game: each clear on a real tripped loop.
