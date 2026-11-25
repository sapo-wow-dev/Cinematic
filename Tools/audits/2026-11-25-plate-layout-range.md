# Plate Layout: one range for every way of moving, kept in view (fix card)
Fix: the Layout tab's number boxes stopped at 150 across and 100 up or down, while dragging and the arrow keys had no
limit, and a part dragged off the preview couldn't be grabbed again.
Found by: audit 2026-11-25; the range is the user's pick ("Bigger range, kept in view")
Code: Plates/PlateLayout.lua: ns.PLATE_LAYOUT_RANGE, Clamp (applied to parts, the soft target, Custom's shift);
Plates/PlateLayoutPage.lua: the drag, the arrow keys, the boxes, Redraw's fit
Clients: forever (no Layout tab on retail)
Base: HEAD

## Before / after
- Before: Left / right -150..150 and Down / up -100..100 in the boxes; dragging and the arrows any distance (a box
  then showed 300, and one wheel step snapped it to 150). Custom's shift -100..100 / -60..60. A part dragged past the
  preview's edge was out of sight and out of reach (only Reset part brought it back).
- After: 250 across and 150 up or down everywhere: boxes, dragging, arrow keys, Custom's shift, and a saved or
  shared layout past it is held to it on the plates. After a change, the preview draws the plate smaller and moves
  it over when a part would leave the stage, so every part stays in view and can be grabbed.

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased; no saved layout past the range.
- Other features, other addons: none read part offsets but PlateLayout.lua.
- Tests that encode it: none; Tools/offline/platelayout.lua's moves are all inside the range.

## States (the matrix)
The level box saved 245 or 400 right; Shift+Right three times, or Left once.
Test: Tools/offline/platelayoutrangematrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-range | start=245 action=shiftRight3 | x=260 | x=250 |
| platelayout-range | start=400 action=shiftRight3 | x=415 | x=250 |
| platelayout-range | start=400 action=left1 | x=399 | x=250 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab only, unreleased. Pinned offline: the keys on the real page, the engine holding a saved 400 to
250 and a Custom shift to -250 (Tools/offline/platelayout.lua). Not offline: dragging (cursor-driven) and the
preview's fit as it looks (the in-game run).
