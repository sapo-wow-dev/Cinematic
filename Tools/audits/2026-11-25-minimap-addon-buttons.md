# Minimap: addon buttons made without LibDBIcon (fix card)
Fix: the Addon buttons row only knew LibDBIcon's buttons (LibDBIcon10_*): buttons an addon makes itself on the minimap (Journey Tracker, Panorama, MSBT, Battle Text Forever, EllesmereUI's) stayed up with the row hidden, and weren't on the Frames pages
Found by: player case (Discord, rudy, 2026-11-25: Journey Tracker's button)
Code: Frames.lua: IsAddonMapButton (new), ns.FindMinimapHeader (the scan, the gathered let-go, FindCoords), ns.ReportMinimapIcon
Clients: both
Base: badf2f0

## Before / after
- Before: with Minimap > Addon buttons hidden, LibDBIcon buttons faded and a hand-made one (JourneyTrackerMinimapButton) stayed at full. It faded only with the whole minimap.
- After: any button an addon made on the Minimap (a named Button the game's taint record says an addon made, issecurevariable) fades with the Addon buttons row, comes back on minimap hover like the others, and is let go once an addon that gathers buttons takes it. Game buttons, named pins (GatherMatePin<n>), named Frames (pin holders) and unnamed buttons are left as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FindMinimapHeader minimapaddons LibDBIcon10_ IsAddonMapButton`)
- Players: anyone with Addon buttons hidden and one of those addons: the button now hides too (what the row says). Built-in profiles Cinema and Shoulder Cam hide the row in instances (instanceShow.minimapaddons=false): those buttons now hide there too.
- Other features: minimap hover group (has the Addon buttons row: the new buttons come back on hover with the rest); coordinates search skips addon buttons (now these too: none is a coordinates text).
- Other addons: Leatrix Plus hides non-LibDBIcon buttons and shows LibDBIcon10_LeaPlusCustomIcon_* copies (those were already faded; the hidden originals now faded too, no change seen). MinimapButtonButton gathers them off the map: let go (pinned: gathered=yes). EllesmereUI: its EllesmereUIMinimapButton was listed in Tools/offline/addon-frames/EllesmereUI.txt as "minimap row": now on the Addon buttons row, note updated. A Support file's ns.LeaveAlone of a button's name still keeps it out (AddFrame checks leftAlone).
- Tests that encode it: none (refs: no Dev test, ledger, engine rule or card on this path).

## States (the matrix)
The states this code reads: the child's kind (LibDBIcon, hand-made addon button, game button, named addon pin Button, named addon Frame, unnamed button), the Minimap page (showInMinimap), the minimap left alone by a Support file, and the button gathered off the map later. Client fixed per run.
Test: Tools/offline/minimapaddonbuttonsmatrix.lua forever
Test: Tools/offline/minimapaddonbuttonsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| minimap-addon-buttons | leftalone=no kind=handmade page=on gathered=no | no | faded |
| minimap-addon-buttons | leftalone=no kind=handmade page=on gathered=yes | no>no | faded>no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: players with a hand-made addon minimap button and Addon buttons hidden now see it hide (what they asked for). Pinned offline: game buttons, pins, frames and unnamed buttons untouched, page off and left alone untouched, both clients. Not proven offline: issecurevariable(name) giving false for an addon's frame name in game (the addon test, Dev/AddonTest.lua, already relies on it on Forever), and the button's own look while faded and hovered: the in-game addontest run for JourneyTracker. Proven in game 2026-11-25 (Forever, test queue qf0dd, addonkit JourneyTracker): JourneyTrackerMinimapButton faded with the Addon buttons row (alpha 0.00), stayed hidden and came back (1.00), every frame covered, 8 pass 0 fail.
