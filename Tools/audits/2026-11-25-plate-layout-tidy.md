# Plate Layout: the parts list says each part's state; the page tidied (fix card)
Fix: the parts list never said which parts were on the preview or hidden by your game's settings; Preset sat alone at
the top row's far end; the fields left gaps where one didn't apply to the picked part.
Found by: audit 2026-11-25 (findings 7 and 8)
Code: Plates/PlateLayoutPage.lua: RowStates (new), the refresher's field flow, Preset's and Own layout's places, Pick
(only a click in the list takes the keys)
Clients: forever (no Layout tab on retail)
Base: HEAD
Test: Tools/offline/platelayoutkeysmatrix.lua forever

## Before / after
- Before: every row in the parts list looked alike; Preset at the far right of the top row; Size, Gap and Hang on
  left empty rows when hidden. Picking a part by code (the tests, the page's own Select) took the keyboard as a click
  did.
- After: a row is white while its part is on the preview, dim while it isn't up (picking it brings it up), grey with
  "off" when your game's settings hide it. Preset sits beside Layout for, Own layout after it (a kind's only). The
  fields close up: each row only where it applies. Only a click on a row takes the keys (fix card
  2026-11-25-plate-layout-keys.md's behavior; its matrix unchanged).
- Kept as it is: the Center heading's grey value text, as every Look panel's segmented control shows its pick.

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased.
- Tests: Dev/PlateMatchTest.lua's every-part step now also checks each row (white on the preview, "off" when
  hidden): in game. Tools/offline/platelayoutpage.lua and the keys matrix unchanged.

## States (the matrix)
The keys matrix (the click that takes the keys is a row's; the cells call the same way: unchanged).

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| none | | | |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab's look only, unreleased. Not offline: the rows' colors and the fields' flow as they look (the
in-game run's shots and its row check).
