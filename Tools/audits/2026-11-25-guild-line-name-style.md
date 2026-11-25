# Nameplates: the title and guild line follow Name Style's switches, and Service NPCs' kinds their tab (fix card)
Fix: with Name Style off, Enable Style off or Style left out, the line under plate names still took Name Style's size, opacity, font, outline and shadow, and titles still turned into icons or kept their brackets; the Service NPCs kinds still counted with their Names tab off
Found by: audit 2026-11-25 (gating, finding C11 in 2026-11-25-gating-findings.md)
Code: Plates/PlateGuild.lua: NameStyled, KindOn, KindsFresh (new), IconSize, LineText, ns.DescribePlateTitle, ServiceIcon, PlateQuestGiver, ns.PlateServiceMatch, ns.PlateServiceKind, guildLine.S, Refresh
Clients: both
Base: baabf86

## Before / after
- Before: Name Style's All names set to a bigger, fainter second line with Brackets kept (or Icons), then
  Name Style switched off (or Enable Style off, or Load Style unticked): NPC titles and guild names stayed
  bigger and fainter in that font and shadow, and titles kept their brackets or showed as icons. The Names
  grid's Service NPCs tab right-clicked off: Vendors (and every kind ticked) still kept those NPCs' names up.
- After: Name Style off (any of the three): the line in the game's look, titles as a fresh profile has them
  (no brackets, no icons). The Service NPCs tab off: its kinds count as unticked (and their icons too), worked
  out again as the tab flips.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateServiceMatch PlateServiceKind nameServiceIcons nameServiceBrackets NameLine2Look`)
- Players: anyone with a Name Style second line or titles look and Name Style off: now the game's look, as the
  switch says. Anyone with the Service NPCs tab off: those NPCs' names no longer kept by that row.
- Other features: Effects.lua (keeps a plate's name by ns.PlateServiceMatch), Name Style's rows
  (ns.PlateServiceKind picks a service NPC's row), /cine debug names (DescribePlateTitle now shows the
  ticks as they apply). The Name Style preview reads NameLine2Look with its own S: unchanged.
- Other addons: none.
- Tests that encode it: guildlinealloc, talknames, talknamesmatrix: PASS, both clients.

## States (the matrix)
Enable Style on or off, Name Style's switch, Icons on or off, the Service NPCs tab on or off, the client (a
title shown alone, Brackets kept, a bigger fainter second line set).
Test: Tools/offline/guildlinestylematrix.lua forever
Test: Tools/offline/guildlinestylematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| guild-line-name-style | icons=off tab=on | line=<Baker> alpha=half size=big kept=yes | line=Baker alpha=full size=usual kept=yes |
| guild-line-name-style | icons=off tab=off | line=<Baker> alpha=half size=big kept=yes | line=Baker alpha=full size=usual kept=no |
| guild-line-name-style | icons=on tab=on | line=icon alpha=half size=big kept=yes | line=Baker alpha=full size=usual kept=yes |
| guild-line-name-style | icons=on tab=off | line=icon alpha=half size=big kept=yes | line=Baker alpha=full size=usual kept=no |
| guild-line-name-style | style=on page=on icons=off tab=off | line=<Baker> alpha=half size=big kept=yes | line=<Baker> alpha=half size=big kept=no |
| guild-line-name-style | style=on page=on icons=on tab=off | line=icon alpha=half size=big kept=yes | line=none alpha=- size=- kept=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with Name Style (or Enable Style) off and a second line look of their own, or the Service
NPCs tab off, see a change. One switch read per line refresh. Not proven in game: a real plate's line redrawn
at once on the switch's flip (it redraws as the plate next lays out, PlateParts), and that the tab's flip
reaches Effects' keep (C1, the Nameplates tabs, is its own fix).
