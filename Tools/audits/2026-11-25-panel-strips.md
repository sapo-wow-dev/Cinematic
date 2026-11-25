# Windows: no rearranging and no drag strips with the switches off (fix card)
Fix: once a drag strip had ever been made, every window opening or closing (and the bags, the loot window, the roll frames) still rearranged the windows with Drag windows, Open windows clear and the Quality of life page off; the strips also stayed up till the next window opened
Found by: audit 2026-11-25 (gating, finding D8 in 2026-11-25-gating-findings.md)
Code: QoL/CenterPanels.lua: stripsUp (new), Arrange, PlaceOther, Placed, ns.RefreshPanelStrips (new); Options.lua: the Quality of life switch's onChange; Profiles/Profiles.lua: SettingsChanged
Clients: both
Base: baabf86

## Before / after
- Before: drag a window once, then turn Drag windows (or the whole Quality of life page) off: the strip on
  the open windows stays up, and every window opening and closing for the rest of the session still runs
  the full arrange pass twice (now and a frame later).
- After: switching the page off (or a profile with it off) takes the strips down at once; with nothing on,
  the next window opening takes down any strip left and from then on a window opening does nothing.

## Who relies on the old behavior
(`python -I Tools/audit.py refs Placed Arrange RefreshPanelStrips dragPanels centerPanels`)
- Players: none with the switches off; with them on, the same passes.
- Other features: Quest Vision's talk window place and the shop following it (ns.TalkWindowPlace,
  ns.ShopFollowsTalk) still keep the passes on by themselves, as before; their strips (CanDrag) stay up.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
A strip made first; then Drag windows, Open windows clear, the Quality of life page each on or off;
the change seen by a window opening or by the page's refresh; then another window opens.
Test: Tools/offline/panelstripsmatrix.lua forever
Test: Tools/offline/panelstripsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| panel-strips | by=window page=off | rearranged=yes strip=down | rearranged=no strip=down |
| panel-strips | by=window drag=off center=off | rearranged=yes strip=down | rearranged=no strip=down |
| panel-strips | by=refresh page=off | rearranged=yes strip=up | rearranged=no strip=down |
| panel-strips | by=refresh drag=off center=off | rearranged=yes strip=up | rearranged=no strip=down |
| panel-strips | by=refresh drag=off center=on page=on | rearranged=yes strip=up | rearranged=yes strip=down |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the passes and the strips are the same with the switches on. Unticking Drag windows alone (its box
has no refresh of its own) still leaves the strips up till the next window opens, as before; the page
switch and a profile take them down at once. Not proven offline: real windows (the matrix uses the bags
and a stand-in ShowUIPanel).
