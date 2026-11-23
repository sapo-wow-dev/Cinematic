# Style: a read plate color back after a full-color theme (fix card)
Fix: leaving a full-color plate theme (Sunset's), a plate whose color was read from its bar (retail) stayed white until the game painted it again.
Found by: audit 2026-11-22 (Tools/audits/2026-11-22-style-plate-full-white.md, "Found next to it")
Code: Style/PlateHealthStyle.lua: Full() (the bar's color read for the strip)
Clients: both (only retail reads a plate bar's color; Forever reads white)
Base: 2deb1a9

## Before / after
- Before: with a full-color plate theme (Sunset), a plate whose color Full() read from the bar (the game hadn't set
  it again since our hook went on) stayed white after switching to another theme or the game's look, until the game
  painted it again.
- After: that plate's fill gets the color that was read back, as a plate whose color the game had set always did.

## Who relies on the old behavior
(`python -I Tools/audit.py refs DressPlateFullColor StyleTextureFull`, as the 2026-11-22 card.)
- Players: anyone leaving a full-color nameplate texture (a theme's or a row Look's) on retail.
- Other features: state.color is also read by Shade() (a row gradient's start color) and Gradient() (flat again).
  A read color is a known, non-white number triple, the same kind ColorSet keeps; the game's next set replaces it.
- Other addons: none.
- Tests that encode it: Tools/offline/platefullmatrix.lua (pins the right answer, fails on the old code),
  Tools/offline/platefullwhite.lua. No ledger, rule or card.

## States (the matrix)
As the 2026-11-22 card: had full or never; color source read / kept / none; strip takes or refuses; left by off or
gradient; then nothing or a recolor; per client. 48 cells.
Test: Tools/offline/platefullmatrix.lua forever
Test: Tools/offline/platefullmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-full-fill | had=full source=read strip=takes leave=off again=no | fill=white strip=hidden | fill=game strip=hidden |
| plate-full-fill | had=full source=read strip=refuses leave=off again=no | fill=white strip=hidden | fill=game strip=hidden |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one line, only on the read branch (a known color that isn't white: never a secret, never Forever's white read,
so Forever's real plates are unchanged); 46 of 48 cells unchanged per client, the 2 changed ones declared. Not proven
offline: the real plate flow on retail (does GetStatusBarColor read the fill's vertex color, white once whitened:
the white filter keeps that out of state.color), and a theme reaction color taking the read's place (no read, so
nothing kept: as before).
