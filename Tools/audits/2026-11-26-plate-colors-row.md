# Nameplate Style: Default's colors stay under a row that colors nothing (fix card)
Fix: players with Default's Colors set lost them on every plate a Smart row fit with a Plate color, even a row that colors no part (the Mouseover row as it comes, an aggro row on Same with nothing ticked)
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Plates/PlateParts.lua: PlateLook (decided)
Clients: both
Base: e0ca906

## Before / after
- Before: a plate a row fit whose Plate color wasn't Don't change took the row's colors and nothing else: the
  parts the row didn't tick went back to the game's, and a row that ticks none (the Mouseover row out of the box:
  Same as its mark, nothing ticked) took Default's kind and name colors off the plate under the mouse.
- After: a row takes over only the parts it colors; the others keep Default's colors (the bar the kind's, the name
  the name's). A row on The game's still leaves the whole plate the game's.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateLook PlateKinds.Parts PlateDefaultColoursOn`, every hit read.)
- Players: only those who set a Default color (they start at The game's). The Mouseover row and the aggro rows
  default to Same as their mark with no part ticked: under the mouse a plate now keeps its Default colors.
- Other features: RefreshTargetArrow (the parts' kinds to TintTarget), /cine debug plates. The editor's preview
  (PlateRowLook.lua) already drew Default's colors under a row's own (paintBar / paintName): unchanged, now the
  same as the plates.
- Other addons: none.
- Tests that encode it: none (Tools/offline/platekindcolors.lua checks the colors, not which row wins).

## States (the matrix)
The row that fits (none; your target's row on Don't change, The game's, Same as its mark with nothing ticked, My own
with the bar, the name or every part ticked; the Mouseover row as it comes) x Default's colors (none, the kind's bar
color, the name's, both), Smart and Default's colors both shown (Always), the client.
Test: Tools/offline/platecolorsrowmatrix.lua forever
Test: Tools/offline/platecolorsrowmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-colors-row | row=same-none default=bar | name=- bar=- border=- | name=- bar=kind border=- |
| plate-colors-row | row=same-none default=name | name=- bar=- border=- | name=name bar=- border=- |
| plate-colors-row | row=same-none default=both | name=- bar=- border=- | name=name bar=kind border=- |
| plate-colors-row | row=mouseover default=bar | name=- bar=- border=- | name=- bar=kind border=- |
| plate-colors-row | row=mouseover default=name | name=- bar=- border=- | name=name bar=- border=- |
| plate-colors-row | row=mouseover default=both | name=- bar=- border=- | name=name bar=kind border=- |
| plate-colors-row | row=custom-bar default=name | name=- bar=row border=- | name=name bar=row border=- |
| plate-colors-row | row=custom-bar default=both | name=- bar=row border=- | name=name bar=row border=- |
| plate-colors-row | row=custom-name default=bar | name=row bar=- border=- | name=row bar=kind border=- |
| plate-colors-row | row=custom-name default=both | name=row bar=- border=- | name=row bar=kind border=- |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players who set a Default color, on plates a row fits. Pinned: every row kind against every Default color,
The game's still whole. Not proven offline: the painter blending a row's part and a Default part on one plate in
game (two colors, each at its own level), and the name's colored copy (Fill) taking it.
