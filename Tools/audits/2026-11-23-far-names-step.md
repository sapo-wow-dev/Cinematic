# Plates: far names step from you, not the camera (fix card)
Fix: in CineMode on WoW Forever, untargeted names shrank by a third in one jump (Far names smaller, the game's plate step, nameplateMinScale 0.65) about 41 yards from the CAMERA, so zooming alone made names jump (the user: "fix the jump ... so its not such a big jump", then "from your character")
Found by: audit 2026-11-23 (namejump runs 15-18, zoomstep run 1)
Code: Effects.lua: ns.plates.FAR_NAME_CVARS, ns.plates.FarStep / FarWanted / FarStepChanged; Plates/PlateParts.lua: plateSightNear.out / Decide, UpdateLook; Options.lua: Name Style page's Size (Size by, Far names); Core.lua: plateNameSizeBy, plateNameFarStep
Clients: forever
Base: 24882c3

## Before / after
- Before: in CineMode, an NPC you haven't targeted dropped from 0.64 to 0.42 plate scale (its name with it, -35%) the moment the camera passed ~41 yards from it: walking, or just zooming out a yard (zoomstep: you moved 0.00 yd, the step came between zoom 4 and 5). Your target never stepped.
- After: in CineMode (every plate on, names styled, Forever) the game's plates are held ONE size (nameplateMinScale = nameplateMaxScale = 1; your distances kept), so zooming never scales them; yours back outside it. The old set's leftover distances 41 / 5 (no saved value of yours left: zoomstep and farnames runs) go back to the game's defaults once. Our names more than 28 yards from YOU are one step smaller, the Name Style page's Far names (Same size / A bit smaller 0.9 / Smaller 0.8, the default / Much smaller 0.65); zooming never moves it. Read out of fights only (CheckInteractDistance 4, already read for the sight check); in a fight a name keeps its size. A change holds a second before it shows (a unit walking on the line doesn't flip). Also new: Size by Zoom (as before) / Fixed (one size at any zoom).

## Who relies on the old behavior
(`python -I Tools/audit.py refs FAR_NAME_CVARS nameplateMinScale`, every hit read.)
- Players: nobody's saved settings: it was a CVar set CineMode held and let go (your own value back after). New settings plateNameSizeBy (zoom) and plateNameFarStep (0.8) default to the old look's sizes.
- Other features: Effects.lua UpdatePlates and the release only hold or let go; nothing else reads the value.
- Other addons: none (Support/ has no hit).
- Tests that encode it: Dev/FarNamesTest.lua (held the set, plates at its min: rewritten to check the set NOT held and our step); Dev/NameScaleTest.lua namejump's walk 2 (Far names smaller off by ns.farNamesTestOff: now the same as walk 1) and zoomstep (the game's step by zoom: proof of the old behavior); Tools/offline/namejump.lua's stand-in plate (made-up world, unchanged); ledger name-scale.md Q13/Q14/Q16/Q18 (history, true for their runs); engine rules forever.plate.no-distance-scale and forever.plate.selected-no-distance-scale (game facts, unchanged).

## States (the matrix)
CineMode on/off, Name Style on/off, the Nameplates page on/off, outside or in an instance, in a fight or not, the client.
Test: Tools/offline/farnamesmatrix.lua forever
Test: Tools/offline/farnamesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| far-names-step | client=forever cine=on style=on plates=on place=outside fight=no | min=0.65 max=1 maxDist=41 minDist=5 held=true | min=1 max=1 maxDist=10 minDist=10 held=true |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Dev/FarNamesTest.lua | step 1 "held, every value as set"; step 2 "plate(s) at 0.65 of the full" | the game's step held, plates at its min | the step NOT held; plates one scale; our far names at Far names' step | the user 2026-11-23: "Yes, OK" (0.65 -> the set's own), then "Yes, OK" (the rewrite) |

## Risk
medium: every Forever player in CineMode with names styled. Far names now step once at ~28 yards from you instead of ~41 from the camera (nearer, and fixed to you); the default step is 0.8, smaller than the old 0.65. In fights the step isn't read: names keep the size they had, a name first seen in a fight is full size. Pinned offline: plates held one size only in CineMode's cell, yours in the other 31, both clients; the leftovers put back once; Decide's first reading and one-second hold; past 28 yards 0.8 of near at zoom 2, 8, 15; Same size none (Tools/offline/namescale.lua). Not proven offline: the on-screen sizes and the 28-yard reads (in game: /cine debug farnames).
