# Cameras: your own triggers stop with the Triggers page, the Scenes page or Enable Cameras off (fix card)
Fix: your own triggers kept their 0.1 s loop and game events with the Triggers page off, and with the Scenes page or Enable Cameras off they still fired (the Triggers log's "fired", the death and tele cameras' pretend times)
Found by: audit 2026-11-25 (gating, finding D7 in 2026-11-25-gating-findings.md)
Code: Camera/CustomTriggers.lua: YoursOn (new), TryStart, Tick, SyncNow
Clients: both
Base: baabf86

## Before / after
- Before: scenes of yours with triggers. Triggers page off: none starts, but the 0.1 s loop and the
  events (casts, auras, zones) run on. Scenes page or Enable Cameras off: they still fire, log "fired",
  and a death-camera one still sets the death test time, a tele one its pretend cast.
- After: any of the three off: no loop, no events, nothing fires; one playing ends. Back on, they're
  back within a second (the 1 s check that already brings the scenes in line).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SyncCustomTriggers cameraTriggers cameraScenes`)
- Players: none want triggers firing for scenes that can't play (TriggerRowNow already gave no camera
  with the Scenes page off).
- Other features: built-in sources registered by SyncNow (ns.RegisterTriggerSource) are kept either
  way; the Triggers page's Fire now (ns.FireLibTrigger) is unchanged; scene keys (Cinematic_CustomTrigger)
  do nothing while off, as with the Triggers page off before.
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
The Triggers page, the Scenes page and Enable Cameras each on or off, with a key scene and a buff scene.
Test: Tools/offline/yourtriggersoffmatrix.lua forever
Test: Tools/offline/yourtriggersoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| your-triggers-off | triggers=off | loop on, events on, key no | loop off, events off, key no |
| your-triggers-off | triggers=on scenes=off | loop on, events on, key fired | loop off, events off, key no |
| your-triggers-off | triggers=on scenes=on cameras=off | loop on, events on, key fired | loop off, events off, key no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with a page off. Back on takes up to a second (the 1 s sync). Not proven offline: the game's
events, a playing script scene ending as the page goes off.
