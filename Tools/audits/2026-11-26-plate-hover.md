# Nameplate Style, Name Style, Nameplate Layout: pointing at a choice never saves anything (fix card)
Fix: hovering a choice whose field writes more than its own value left those writes saved: a Smart row's Plate color ticked Bar in it, Name Style's Letters > "Its own" copied the name's font to the second line, Nameplate Layout's Center / Balance / Hang on / Side started a kind's own layout
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17; the open half of Tools/audits/2026-11-25-style-editor-hover.md)
Code: Style/Studio/Frames/Nameplates.lua: PlateColorField, LayoutField (center, count, to, side); Style/Studio/Frames/Names.lua: Field (Line2Match). noHover, honored by Studio.ShowFor (Editor.lua) and Host:Snapshot (Studio.lua)
Clients: both (Nameplate Layout: Forever only)
Base: e0ca906

## Before / after
- Before: pointing (without clicking) at a Plate color on a Smart row whose plate parts were all unticked (an aggro
  row as it comes) ticked "Bar in it" for good: setting the saved color back doesn't untick it. Pointing at "Its own"
  in Name Style's Second line > Letters copied the name's font, outline, outline color and shadow into the second
  line's own settings (5 saved), though Letters stayed "Match the name". On Nameplate Layout (Forever), pointing at
  any Center, Balance, Hang on or Side choice with Layout for on a kind (Hostile, Neutral, Friendly NPCs, Players)
  gave that kind its own layout, a copy of All plates' as it was then (so later All plates changes no longer reached
  it); on All plates it left an empty part table in plateLayoutData.
- After: these choices aren't drawn on the preview while pointed at (as every field marked noHover, the Mirror
  switch beside them); nothing is saved until clicked. A click does what it did.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateColorField LayoutField Line2Match noHover`, every hit read.)
- Players: anyone who pointed at those choices since 679e735 may have Bar in it ticked on a row, a second line's own
  font copy (unused while Letters is Match the name), or a kind's own layout started; not undone here (as the
  2026-11-25 card).
- Other features: Studio.ShowFor and Host:Snapshot are the only readers of noHover. ns.PlateLayoutRecord (drags,
  arrow keys) uses LayoutField's x and y only: no noHover there. Names' Field is shared by every Name Style setting:
  only Line2Match is marked. The sliders (Layout's x, y, scale, gap, cx, cy) still preview on hover.
- Other addons: none.
- Tests that encode it: Tools/offline/stylestudio.lua 2b (its frames list gains names and platelayout: added checks
  only, all PASS; the old checks unchanged), Tools/offline/styleeditorhovermatrix.lua (unchanged).

## States (the matrix)
The field (Plate color, Letters, Center, the level box's Balance, Hang on and Side), the variant it's edited on
(Default / All plates, a row or kind: target, Enemies, hostile; an aggro row for Plate color), its saved value (as
it comes, or its second choice picked through its own set), the choice hovered (by place, and the last). Each cell:
whether any saved setting changed after the hover (deep, defaults read for unsaved) and what the preview drew.
Retail: Layout's page isn't there ("no frame"). Per client (Layout's cells change on Forever only).
Test: Tools/offline/platehovermatrix.lua forever
Test: Tools/offline/platehovermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-hover-forever | field=plateColor on=row | * | db=unchanged drawn=none |
| plate-hover-forever | field=plateColor on=aggro | * | db=unchanged drawn=none |
| plate-hover-forever | field=letters | * | db=unchanged drawn=none |
| plate-hover-forever | field=center | * | db=unchanged drawn=none |
| plate-hover-forever | field=balance | * | db=unchanged drawn=none |
| plate-hover-forever | field=hang | * | db=unchanged drawn=none |
| plate-hover-forever | field=side | * | db=unchanged drawn=none |
| plate-hover-retail | field=plateColor on=row | * | db=unchanged drawn=none |
| plate-hover-retail | field=plateColor on=aggro | * | db=unchanged drawn=none |
| plate-hover-retail | field=letters | * | db=unchanged drawn=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

(That these choices don't preview on hover: OK'd by the user 2026-11-26, as the 2026-11-25 card's.)

## Risk
low: only the hover preview of these choices goes (they never showed safely); a click does what it did. Not proven
offline: in game, pointing at them draws nothing on the preview (the "Preview: not saved" badge may still show, as
for any row). Side was not in the audit's list (Center, Balance, Hang) but writes the same way: marked too.
