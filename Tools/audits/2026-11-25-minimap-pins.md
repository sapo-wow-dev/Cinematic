# Minimap: Questie's quest icons aren't addon buttons (fix card)
Fix: Questie's minimap quest icons (QuestieFrame<n>, named Buttons on the Minimap) were taken for addon buttons since 3091bab: with Addon buttons hidden they vanished while the minimap showed
Found by: player case (2026-11-25: Questie's minimap icons fade with the Addon buttons row)
Code: Frames.lua: IsAddonMapButton, IsMapPin and InPins (new)
Clients: both
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: Minimap > Addon buttons hidden, the minimap shown: every Questie quest "!" and "?" on the minimap faded with the addon buttons (Questie makes them with CreateFrame("Button", "QuestieFrame"..id), and HereBeDragons-Pins parents them to the Minimap). The same for any addon's pooled minimap pin that's a named Button, and any pin a HereBeDragons copy keeps there.
- After: a name ending in its number (QuestieFrame<n>, not <...>Button<n>) and any frame in a HereBeDragons minimapPins list (the shared LibStub copy, Questie's by its LibStub name, or Questie's own HBDPins module) is a pin, not a button: left with the minimap. The buttons 3091bab meant (LibDBIcon10_*, JourneyTrackerMinimapButton, PanoramaMinimapButton, MSBTForeverMinimapButton, BattleTextForeverMinimapButton, EllesmereUIMinimapButton, GamepadXIVMinimapButton) fade with the row as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsAddonMapButton QuestieFrame minimapaddons minimapPins`, read every hit.)
- Players: anyone with Questie and Addon buttons hidden (built-in profiles Cinema and Shoulder Cam hide it in instances, instanceShow.minimapaddons=false): Questie's icons now stay with the minimap there. Nobody wanted them gone: they're the map's content.
- Other features: ns.FindMinimapHeader (the scan and the gathered let-go), FindCoords (skips addon buttons: pins are now looked into, depth 1, as before 3091bab), ns.ReportMinimapIcon (/cine debug mapicon lists fewer frames). Support/QuestieMinimap.lua reads the same minimapPins lists (Reveal), untouched.
- Other addons: Questie (its icons), GatherMate (already excluded by its Pin name), any addon with HereBeDragons pins. MinimapButtonButton / Leatrix Plus gather only real buttons: unchanged.
- Tests that encode it: Tools/offline/minimapaddonbuttonsmatrix.lua (3091bab's: its hand-made names end in a number, JourneyTrackerMinimapButton<n>: kept as buttons by the Button<n> exception; unchanged both clients). Tools/engine/rules/ui-frames.lua forever.minimap.addon-buttons-by-taint ("pins named *Pin<n> excepted"; says Questie's pins are Frames in QuestieFrameGroup: its icons are Buttons straight on the Minimap, pins.Minimap = Minimap in Questie's HereBeDragons copy; the rule's text is left for the user). Tools/offline/addon-frames/Questie.txt and Tools/addon-kit/addons/Questie.md say the same QuestieFrameGroup thing: not changed here.

## States (the matrix)
The states this code reads: the child's name kind (Questie's icon, a pooled pin, a plain-named pin, each real button by its installed name, a <Addon>MinimapButton<n>), which pin library lists the pins (none, HereBeDragons-Pins-2.0, HereBeDragonsQuestie-Pins-2.0, QuestieLoader._modules.HBDPins), the Minimap page on/off. Client fixed per run. (Left alone and gathered are 3091bab's matrix, kept unchanged.)
Test: Tools/offline/minimappinsmatrix.lua forever
Test: Tools/offline/minimappinsmatrix.lua retail
Test: Tools/offline/minimapaddonbuttonsmatrix.lua forever
Test: Tools/offline/minimapaddonbuttonsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| minimap-pins | kind=questie page=on | faded | no |
| minimap-pins | kind=pooled page=on | faded | no |
| minimap-pins | kind=hbdpin pinlib=hbd page=on | faded | no |
| minimap-pins | kind=hbdpin pinlib=questiehbd page=on | faded | no |
| minimap-pins | kind=hbdpin pinlib=questiemodule page=on | faded | no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: players with Questie (or another addon's named pins) and Addon buttons hidden see their quest icons stay on the minimap. Pinned offline: every real button name installed still fades, whatever pin library is loaded, page off untouched, 3091bab's matrix unchanged, both clients. Not proven offline: Questie's icons in game with Addon buttons hidden (an addon test run for Questie: QuestieFrame<n> on the Minimap stays at the minimap's alpha), and an addon button somewhere whose name ends in a number without "Button" (none installed, 2026-11-25): it would now stay up.
