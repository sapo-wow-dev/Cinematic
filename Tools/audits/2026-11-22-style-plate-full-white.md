# Style: nameplates' color back after a full-color theme (fix card)
Fix: a full-color texture (Sunset's) whitens a plate's fill and puts its color on a strip; leaving it, only a plate whose strip had shown got its color back, so one whose strip refused the color (a secret) stayed white.
Found by: audit 2026-11-22 (landed in bdb2e1d; this card written after, retroactively)
Code: Style/PlateHealthStyle.lua: ns.DressPlateFullColor() (whitened), Full() (the way back)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: with a full-color plate theme (Sunset), a plate whose color the game kept secret (no strip under it)
  stayed white after switching to another theme or the game's look, until the game painted it again.
- After: that plate's fill gets the bar's last known color back, as a plate whose strip showed always did.

## Who relies on the old behavior
(`python -I Tools/audit.py refs DressPlateFullColor StyleTextureFull`, read every hit.)
- Players: anyone switching away from a full-color nameplate texture (a theme's or a row Look's), mostly on
  Forever (plate colors read white or secret there).
- Other features: the previews call ns.DressPlateFullColor too (PlateRowLook.lua, PlateThemes.lua,
  GeneralStyle.lua); they only set `whitened`, which only Full() reads, so nothing changes for them.
- Other addons: none.
- Tests that encode it: Tools/offline/platefullwhite.lua (the bug's state and the shown-strip one). No ledger, rule
  or card.

## States (the matrix)
The plate had the full-color look or never; its color source (read from the bar, as retail; kept from the game's
last set, Forever reading white; none); the strip took the color or refused it; the look left by the theme going
(off) or a row gradient coming on; then nothing, or the game painting a newer color and the plate styled again;
per client. 48 cells. (Full() driven directly, as platefullwhite.lua: the plate's own events aren't stood in.)
Test: Tools/offline/platefullmatrix.lua forever
Test: Tools/offline/platefullmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-full-fill | had=full source=kept strip=refuses leave=off again=no | fill=white strip=hidden | fill=game strip=hidden |

## Found next to it
2 cells per client FAIL on bdb2e1d^, bdb2e1d and the current code alike: **the color read from the bar but not
yet kept** (`source=read`, retail's case, before the game sets the bar's color again after our hook went on), theme
left: the fill stays white (`fill=white`, pinned `fill=game`). Full() reads the bar's color to color the strip but
never keeps it in state.color, and the way back only uses state.color. Not fixed here (report only).

## Open (the user's call)
- `had=full source=none` (no color known anywhere: Forever reads white and none was kept): pinned `fill=white`
  (nothing to put back till the game paints it). Alternative: the unit's selection color.
- `had=full leave=gradient`: pinned `fill=white strip=hidden`: the fill is left for the gradient to paint
  (Gradient() runs before Full() in StylePlate). If the gradient can't go on (a secret color), it stays white.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: one table and one condition; 47 of 48 cells unchanged on both clients, the 1 changed one declared. Not proven
offline: the real plate flow (StylePlate, GameSet, the game's color events), secret colors as real secrets.
