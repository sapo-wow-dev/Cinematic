# Safety stop: everything Cinematic draws is put away, not only the bars, tint, haze and weather (fix card)
Fix: a safety stop (an error that kept repeating, /cine panic) hid the letterbox, tint, haze and weather only; the
Visions, the death screen, cards, the emote card, the camera wheel and the Exit camera box stayed as they were,
frozen when the error was theirs, and tests kept playing.
Found by: overlay audit 2026-11-25 (player case: Teleport Vision stuck on screen till Alt+F4)
Code: Diagnostics.lua: ns.OnSafetyStop / ns.RunSafetyClears (new), the loop clears (G1's) kept for it;
Core.lua: RestoreEverything runs them; explicit clears: Atmosphere/DeathVision.lua (death screen, its test),
Visions/Cards.lua + CombatVision.lua ns.ClearCard (the card on screen, the queue), Camera/Camera.lua (Exit camera box)
Clients: both
Base: 10ee73d

## Before / after
- Before: "stopped for this session ... put your UI back" while a portal, the death screen's gray, a card or the
  camera wheel stayed on screen, frozen, till a reload.
- After: each is put away and reset as the stop comes (the loops' own clean-ups and these). /cine resume brings
  back only what its own moment brings again (you still dead: the death screen; a test: not).

## Who relies on the old behavior
(`python -I Tools/audit.py refs RestoreEverything Suspend`)
- Players: nobody wants overlays left after "put your UI back". Cards waiting behind the one on screen are dropped.
- Other features: features keep running while stopped (not gated by ns.IsSuspended), so a Vision whose moment is
  still on may show again; the stop's purpose here is that nothing stays frozen. Focus and weather are still hidden
  and shown again on resume as before.
- Other addons: none.
- Tests that encode it: safetystopmatrix.lua (game settings), resumematrix.lua (styles' settings),
  weathersuspendmatrix.lua: kept unchanged.

## States (the matrix)
overlay showing as the stop comes (Teleport Vision's test / Death Vision's test / a Zone card / none); each cell:
on screen after the stop, and after /cine resume.
Test: Tools/offline/safetyoverlaymatrix.lua forever
Test: Tools/offline/safetyoverlaymatrix.lua retail
Test: Tools/offline/safetystopmatrix.lua forever
Test: Tools/offline/safetystopmatrix.lua retail
Test: Tools/offline/resumematrix.lua forever
Test: Tools/offline/weathersuspendmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| safety-stop-overlays | overlay=teleport | stop=shown resume=shown | stop=hidden resume=hidden |
| safety-stop-overlays | overlay=death | stop=shown resume=shown | stop=hidden resume=hidden |
| safety-stop-overlays | overlay=card | stop=shown resume=shown | stop=hidden resume=hidden |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: runs only on a safety stop (rare: an error loop, /cine panic). Not proven offline: the emote card, camera
wheel, campfire, sleeping bag, damage display, Vitals and mana clears on a stop (read, not run), and the Exit box.
