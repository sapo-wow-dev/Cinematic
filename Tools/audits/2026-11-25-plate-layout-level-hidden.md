# Plate Layout: crowd control moves in when Cinematic hides the level box (fix card)
Fix: with the level box hidden by Cinematic, crowd control kept a gap the box's width beside the bar, and Balanced
counted the hidden box, for every Forever player who hides the level box (Plate parts grid or a Nameplate Style
row's Look).
Found by: audit 2026-11-25 (the user: "what if we dont have level showing what happens to the cc position?")
Code: Plates/PlateLayout.lua: ApplyPlateLayout, ns.PlateLayoutShift, Extents, ns.PlateLayoutLevelHidden (new);
Plates/PlateParts.lua: ApplyPlate (tells the layout the level box's level)
Clients: forever (retail: no layout, the call returns at once)
Base: f5d5702

## Before / after
- Before: hiding the level box only faded it to nothing. The game still saw it up, so crowd control (roots, stuns)
  stayed where it is beside a level box: about 30 to the right of the bar, with an empty space between. Balanced
  centered the plate on room for the invisible box. Nameplate Style's preview showed it the right way (the box
  really hidden, crowd control beside the bar), so the preview and real plates disagreed.
- After: with the level box hidden, crowd control sits 5 right of the bar, where the game puts it when there's no
  level box, and Balanced measures the plate as it looks: no box, crowd control moved in. A crowd control hung on
  another part in the Layout tab stays where it's hung. Shown again: back beside the box.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateLayoutLevelHidden CrowdControlListFrame look.level`, every hit read.)
- Players: nobody wants the gap; the level box hidden is a setting (Plate parts' Level row, a row Look's Level).
- Other features: PlateParts' ApplyPlate only reports the level now; its fades are unchanged.
- Other addons: none hook the crowd control row.
- Tests that encode it: engine rule forever.plate.crowd-control-row (the game's two places: beside the box when
  shown, else beside the bar) agrees with the after. Dev/PlateMatchTest.lua and Tools/offline/platelayout.lua place
  it beside a shown box only: unchanged.

## States (the matrix)
Level box shown / hidden by Cinematic; the layout: none, crowd control nudged, level box moved, crowd control hung on
the bar; Center: Bar / Balanced.
Test: Tools/offline/platelayoutmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-levelhidden | level=hidden layout=none center=bar | cc=bar+30 shift=0 | cc=bar+5 shift=0 |
| platelayout-levelhidden | level=hidden layout=none center=balanced | cc=bar+30 shift=19 | cc=bar+5 shift=31 |
| platelayout-levelhidden | level=hidden layout=ccNudged center=bar | cc=bar+40 shift=0 | cc=bar+15 shift=0 |
| platelayout-levelhidden | level=hidden layout=ccNudged center=balanced | cc=bar+40 shift=14 | cc=bar+15 shift=26 |
| platelayout-levelhidden | level=hidden layout=levelMoved center=bar | cc=bar+40 shift=0 | cc=bar+5 shift=0 |
| platelayout-levelhidden | level=hidden layout=levelMoved center=balanced | cc=bar+40 shift=14 | cc=bar+5 shift=31 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Forever only, plates whose level box Cinematic hides. The layout now touches those plates' crowd control row
with no layout set (a re-anchor beside the bar, the game's own place for it). Pinned offline: all 16 cells on a
stand-in with real anchor geometry. Not proven offline: the live plate's fade timing (crowd control moves when the
box's fade reaches nothing) and the game re-anchoring the row as it lays plates out (kept by the layout's hooks, as
every moved part); for the in-game run.
