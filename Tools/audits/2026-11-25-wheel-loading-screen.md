# Camera wheel: a loading screen closes it (fix card)
Fix: the wheel waits for its key to be let go; a key let go during a loading screen never came in, so the wheel stayed
open over the whole screen afterwards, taking clicks, till the key, Escape or a fight closed it.
Found by: overlay audit 2026-11-25 (G3: state held by an event that may never come)
Code: Camera/CameraWheel.lua: ns.OnLoadingScreen(ns.CloseCameraWheel) (the shared hook from cb97e07)
Clients: both
Base: 177dde2

## Before / after
- Before: open the camera wheel and get pulled into a loading screen (a summons, a portal): it was still there after.
- After: the loading screen closes it, as Escape does.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CloseCameraWheel`)
- Players: nobody keeps a wheel open through a load on purpose.
- Other features: ns.CloseCameraWheel is what the other wheels call; its OnHide tidies the held key and click mode.
- Other addons: none.
- Tests that encode it: wheelkeytabmatrix.lua (its keybind tab), untouched.

## States (the matrix)
the wheel open (waiting for a click) or closed x a loading screen or not. Opened by its key held: not offline (the
stand-in's key path doesn't open it); the close is the same call either way.
Test: Tools/offline/wheelloadingmatrix.lua forever
Test: Tools/offline/wheelloadingmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| wheel-loading | open=click loading=yes | open | closed |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only on a loading screen with the wheel open. Not proven offline: opened by its key held down.
