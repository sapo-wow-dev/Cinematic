# Style: Nameplate Style off takes a plate theme's ground and bar shape too (fix card)
Fix: with Nameplate Style switched off (Enable Style still on), plates kept the plate theme's dark ground behind the fill and its bar shape
Found by: audit 2026-11-25 (gating, finding C10 in 2026-11-25-gating-findings.md)
Code: Plates/PlateThemes.lua: ns.PlateThemeExtras
Clients: both
Base: baabf86

## Before / after
- Before: a plate theme picked (Clean, say), then Nameplate Style's switch off: the bars went back to the
  game's texture and border, but kept the theme's dark ground behind the fill and its rounded or beveled shape.
- After: Nameplate Style off takes all of the theme away, ground and shape too, as Enable Style off does.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateThemeExtras handlePlateStyle`)
- Players: anyone with a plate theme and Nameplate Style off (with Enable Style on): their plates now look
  like the game's, as the switch says.
- Other features: Style/PlateHealthStyle.lua's Dress (hides its ground and squares the bar again once none
  is given: the same path Enable Style off took), Plates/PlateRowLook.lua's row Look preview. Both now agree
  with ns.PlateThemeBar, which already asked the same switch.
- Other addons: none.
- Tests that encode it: none read PlateThemeExtras offline; stylepagegatematrix, resumematrix PASS.

## States (the matrix)
Enable Style on or off, Nameplate Style's switch on or off, the client (a theme with a ground picked).
Test: Tools/offline/platethemegatematrix.lua forever
Test: Tools/offline/platethemegatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-theme-extras | style=on page=off | texture=game ground=ours | texture=game ground=game |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one switch more, the one the bar's texture already asked. Not proven in game: the ground hidden live on
the switch's flip (Dress runs as the texture goes back, the same call).
