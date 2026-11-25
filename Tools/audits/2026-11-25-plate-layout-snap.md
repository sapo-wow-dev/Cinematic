# Plate Layout: a dragged part snaps to the bar's edges and middle (fix card)
Fix: dragging a part on the Layout tab's preview only snapped back to the game's own place; nothing helped line a
part up with the bar, as the user's mockup had.
Found by: audit 2026-11-25
Code: Plates/PlateLayout.lua: ns.PlateLayoutSnap (new); Plates/PlateLayoutPage.lua: ns.PlateLayoutPageDrag
Clients: forever (no Layout tab on retail)
Base: 29b7920^

## Before / after
- Before: a dragged part went wherever the mouse took it, snapping only to its game place (within 3).
- After: its left edge, middle or right edge snaps to the bar's left edge, middle or right edge when within 4 on
  the screen, the nearest one, and a thin gold line shows what it lined up on. Its game place still wins within 3.
  Dragging the bar itself doesn't snap (it moves the plate).

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased.
- Other features, other addons, tests: none (dragging is the page's own).

## States (the matrix)
The part's left, middle or right; the bar's left, middle or right; 3 or 6 short of it.
Test: Tools/offline/platelayoutsnapmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-snap | short=3 | * | * |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab only, unreleased. The snap pinned offline (all 18 cells). Not offline: the drag itself and the
gold line's place (cursor-driven; the in-game run).
