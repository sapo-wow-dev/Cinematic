# Style: Combat Text Style's General tab switches our numbers and the game's settings off (fix card)
Fix: Combat Text Style's General tab off still drew our numbers, kept the game's damage, heal and pet numbers off, and blanked the game's floating text at login; its 2 s refresh ran with the page off
Found by: audit 2026-11-25 (gating, findings C4 and D15's Combat Text ticker in 2026-11-25-gating-findings.md)
Code: Style/CombatTextStyle.lua: PageOn, By, its refresh timer (now ns.FeatureLoop); Core.lua: the blank world font at ADDON_LOADED; Style/CombatTextPage.lua: RestartPending; Support/DaylightUI.lua: OursOn
Clients: both
Base: baabf86

## Before / after
- Before: Combat Text Style on, its General tab right-clicked off: our numbers still drew over the plates,
  the game's damage (heal, pet) numbers stayed held off, and with Hide all the game's floating text ticked
  the next login still drew the game's text blank (XP included). The page off: its refresh still ran every
  2 seconds for good.
- After: the General tab off is as the page off: no numbers of ours, the game's own settings back, the
  game's font at the next login (the XP row says restart while it differs). The page off: once its game
  settings are let go, its refresh stops; on again, it starts within a second.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshCombatTextStyle CombatTextBy hideWorldText blankWorldFont`)
- Players: anyone with Combat Text Style's General tab off (default on): what that tab says is now true.
- Other features: CombatTextTexts.lua's CT.Shows (by "game": not ours, as On() is off anyway); the page's
  Pet row (PetOurs) greys while the tab is off, as the tab greys it anyway; /cine resume runs the refresh.
- Other addons: DaylightUI's damage font row: the blank font only while the tab is on too.
- Tests that encode it: xpfont, combattextkeep, cvarresetmatrix, resetcvarstest, resumematrix, linecolors,
  linekinds, totemcast, totemhit, fightsfades, platematch, combattextsizematrix, ctpreviewplatematrix:
  PASS, both clients (their tab is on, the default).

## States (the matrix)
A login with the page on or off and its General tab on or off (Hide all ticked, your damage ours), then
two seconds passing; the client.
Test: Tools/offline/combattexttabmatrix.lua forever
Test: Tools/offline/combattexttabmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combat-text-general-tab | page=on tab=off | numbers=on cvar=ours font=blank loop=on | numbers=off cvar=game font=game loop=on |
| combat-text-general-tab | page=off | numbers=off cvar=game font=game loop=on | numbers=off cvar=game font=game loop=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with the General tab off see a change, and it's what the tab says. The page switched on
from elsewhere (a profile) is caught up within about 3 seconds instead of 2. Not proven in game: the game's
floating text font at the next login with the tab off (the blank font is read at login only).
