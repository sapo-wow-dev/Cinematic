# Map pin reveal: test ledger
Goal: the minimap's Reveal can leave out the game's map pin (Map pin box, on), and Shortest Path Forever's journey pin (Not for Shortest Path, shown with SPF loaded, on).
Code: UI/NodeSweep.lua (ns.NodeKind "mappin", ns.MapPinSpot, ns.MapPinIsKnownDot, cursor.Known), Options.lua (Reveal list), Core.lua (defaults), Dev/MapPinTest.lua, Tools/offline/mappin.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Is SPF's minimap reveal trigger its own frames or a game blip? | forever | game blip: it sets the user waypoint per hop (JourneyGuide.lua); its dock pins/route line are addon frames the sweep can't hear | SPF v1.43.11 code |
| Q2 | Can the map pin's name be read in the sweep? | forever | NO, secret like every minimap name | rule forever.minimap.mouseover-names-secret, run 1 |
| Q3 | Does our worked-out pin spot land on the heard dot? | forever | YES, 4.4 yd (run 1), 7.6 yd point (run 2) | rule forever.minimap.user-waypoint-dot |
| Q4 | Box ticked: pin heard as a plain dot (reveals)? | forever | YES | run 2 step 1 |
| Q5 | Box unticked: pin left out as known? | forever | YES | runs 1, 2 |
| Q6 | SPF journey pin left out, and API.Active true while guided? | forever | YES, pin up 1.5-2 s after Navigate | runs 1, 2 |
| Q7 | Real Nearby Dots sweep makes the same call? | forever | YES by code: same CursorSweep/Probe naming; real one only stops at its first node and sweeps a smaller ring | NodeSweep.lua CursorSweep(all) |
| Q8 | Undo after a /reload mid-run | forever | built (CinematicDB.mapPinUndo); not cut off in a run | Dev/MapPinTest.lua |

## Plan tree
Q2 secret -> known-spot way (built). Q3 yes -> done. Real reveal steps (3-4) only add proof of Q7 when the place has no other dots and tracking is on; not needed for the feature.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug mappin | Q3, Q5, Q6 | Q4: test's fault, dots near each other merged into one middle (now judged by points) |
| 2 | 2026-11-21 | /cine debug mappin | Q4, Q5, Q6 again; facing maths | real reveal steps SKIP: tracking off and a quest area nearby; covered by Q7 instead |
