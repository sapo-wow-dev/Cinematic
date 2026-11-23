# Personal Resource Display: our power color left after the page is off (fix card)
Fix: after a druid's form change painted the power bar in our color, turning the page (or its look) off left it in our color until the next form change.
Found by: prdfillmatrix (retro state tests of 7c3e0c1), 2026-11-23; older than the audit
Code: Style/PersonalStyle.lua: the power bar's SetStatusBarColor hook (painted ours without marking the bar as colored)
Clients: both
Base: 2deb1a9

## Before / after
- Before: Bear form with our mana color, shift to caster (the game sets the bar's color, our hook paints ours over
  it), then turn the Personal Resource Display page off: the mana bar stays our color.
- After: the game's color comes back at once, as when our color was put on by the page itself.

## Who relies on the old behavior
- Players: druids (any form change) and any class whose power bar the game recolors, with a custom power color.
- Other features: themes setting the PRD power color (StyleThemes), the PRD fill fix of 7c3e0c1 (same matrix, kept).
- Tests that encode it: prdfillmatrix (pins already said the game's color), prdformfill.lua (fills, kept).

## States (the matrix)
prdfillmatrix: page x fill texture x mana color x the starting form x a form shift x what comes after.
Test: Tools/offline/prdfillmatrix.lua forever
Test: Tools/offline/prdfillmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| prd-power-fill | manaColor=ours start=bear shift=yes after=pageOff | fill=mana grey=n color=ours | fill=mana grey=n color=mana |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (the matrix's pins already said the game's color; the user, 2026-11-23: "Yes, fix all 6") | | | | |

## Risk
low: the hook now marks the bar the way DressBar does (and keeps a secret game color to hand back, as DressBar
does on Forever). Not proven in game: a real shapeshift with the page turned off right after.
