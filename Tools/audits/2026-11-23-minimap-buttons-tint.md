# Minimap Style: buttons' rings keep the game's with the game's look (fix card)
Fix: with the game's look (no theme ring color) and Border color on Theme, every minimap button ring was tinted black on a round minimap
Found by: release review
Code: Style/MinimapStyle.lua: ns.RefreshMinimapStyle
Clients: both
Base: 4d01a3a

## Before / after
- Before: with the default theme (the game's look) and Border color left on Theme, the tracking button, LibDBIcon addon buttons, WoW Forever's day/night dial and square buttons and the addon compartment all turned black-ringed on the round minimap, for most players. (Since 70613ac; the file header says the game's look keeps the game's.)
- After: with no theme ring color, the buttons take the border's color only when the player picked a border color (Black, White, Gold, Class color) or the map is square with a border (its black border's). Otherwise they keep the game's rings, and any tint from before is let go. A theme with a ring color: unchanged (its ring color).

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshMinimapStyle mmButtons mmBorderColor TintButtons`, every hit read.)
- Players: defaults styleTheme game + mmBorderColor theme + mmButtons true: the black rings they saw go back to the game's. No built-in profile sets these.
- Other features: Options.lua, Profiles.lua, GeneralStyle.lua, InterfaceRecolor.lua call RefreshMinimapStyle (no change to what they pass). The page's tooltip ("your theme's ring color, or the border color when it has none") still holds when a border color is picked.
- Other addons: Support/DaylightUI.lua, Support/EllesmereUI.lua only refresh; OthersSkinIt unchanged.
- Tests that encode it: Tools/offline/squaremap.lua reads only the border's color (unchanged). Dev/MinimapSquareTest.lua step "buttons" verdicts `state.buttons > 0` on whatever theme is set: on Forever it runs after the square/border-2 steps (black border: still tinted, passes); on retail with the game's look (square never applies there) it would now see 0 and FAIL. Not edited (not this fix's file): reported for the user.

## States (the matrix)
The states this code reads, each a dimension: theme (game / ringed), Border color (theme/black/gold/class), Square minimap (yes/no), border size (2/0), Color the buttons' rings (on/off), the page (on/off), another addon's minimap (yes/no), the client (retail's matrix, minimap-buttons-tint-retail, has square=no only: the square map never applies there). Every combination is a cell; every cell is pinned in the test.
Test: Tools/offline/minimapbuttonsmatrix.lua forever
Test: Tools/offline/minimapbuttonsmatrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| minimap-buttons-tint | theme=game border=theme square=yes size=0 buttons=on page=on others=no | black | game |
| minimap-buttons-tint | theme=game border=theme square=no buttons=on page=on others=no | black | game |
| minimap-buttons-tint-retail | theme=game border=theme buttons=on page=on others=no | black | game |

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

(70613ac: the Minimap page of its own, its switch minimapStyle (the matrix's page=on), the border colors and the
square map's black border, and Color the buttons' rings working on every theme. On v2.1.27 the rings followed
Interface Recolor's switch (irStyle) and only a theme's ring color, so with the matrix's states every cell kept the
game's. 29 Forever cells, 14 retail (no square map there).)

## Expectations changed
Existing checks, ledger answers or rules whose expectation this fix changes (`audit.py oldtests`, the guard).
Each needs the user's OK before the commit, quoted here.
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (offline) | | | | |

(In game: Dev/MinimapSquareTest.lua "buttons" on retail with the game's look: was buttons > 0, now 0. Its verdict needs the user's call.)

## Risk
low: players on the game's look with Border color Theme see the game's button rings again (what they had before 70613ac). Pinned: all 256 cells per client. Not proven offline: real addon buttons and Forever's dial/square-button art letting go of their tint in game (TintButtons' own untint path, unchanged).
