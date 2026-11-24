# Visual Effects: the edge haze's loop runs only with a haze to draw (fix card)
Fix: at Haze strength 0 (the default since the dofScaleV2 update) the haze's update ran every frame in CineMode drawing nothing
Found by: release review 2026-11-23 (ba78ba3)
Code: Atmosphere/Focus.lua: the ns.FeatureLoop gate
Clients: both
Base: HEAD

## Before / after
- Before: the loop ran whenever CineMode was on with Visual Effects and the Haze switch on (the default), whatever Haze strength said: at strength 0 WantedStrength gave 0 every frame.
- After: it runs only with a haze to draw: Haze strength above 0 or a camera script's own Edge haze (ns.CameraScriptHaze), or a demo or preview showing, or a fade still going. Works for any dofScale value (the Migrations.lua change keeping hand-picked haze is separate). Raising the slider starts it at once (the slider calls ns.FocusPreview, which wakes the loop) and keeps it on after the preview.

## Who relies on the old behavior
- Players: none see a change (nothing drew at strength 0).
- Other features: the Visual Effects page's Haze slider and Preview (ns.FocusPreview / ns.FocusDemo wake the loop), /cine doftest (ns.FocusDemo), DemoHub (ns.FocusDemo), camera scripts' Edge haze (ns.CameraScriptHaze, asked by the gate).
- Other addons: none.
- Tests that encode it: Tools/offline/atmopreview.lua, Dev/AtmosphereTest.lua (sets dofScale 0.6 with a preview: unaffected).

## States (the matrix)
Haze strength 0 / up, a script's Edge haze or none, CineMode on/off, the Haze switch on/off, its Show in row yes/no, a demo or preview showing or not; the client.
Test: Tools/offline/focusloopmatrix.lua forever
Test: Tools/offline/focusloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| focus-haze-loop | strength=zero script=none cine=on dof=on demo=none | loop=on draws=no | loop=off draws=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: nothing drawn changes. At strength 0, a camera script with its own Edge haze starting in CineMode now starts the loop within a second (the once-a-second gate; CameraScripts.lua doesn't wake it), then its 3 s pull in: up to a second later than before. Not proven offline: that delay in game.
