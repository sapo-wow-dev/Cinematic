# Plate Layout: a kind's own layout starts as All plates' (fix card)
Fix: on the Layout tab, the first change to a kind (Hostile, Neutral, Friendly NPCs, Players), or ticking its Own
layout, started that kind's layout empty, so its plates lost every change made for All plates.
Found by: audit 2026-11-25
Code: Plates/PlateLayoutPage.lua: Editing, OwnFromAll (new), the Own layout tick, ns.PlateLayoutPreset (keeps started)
Clients: forever (no Layout tab on retail)
Base: 684f769^

## Before / after
- Before: Layout for on Hostile shows All plates' layout. Nudge one part (or tick Own layout) and Hostile gets a
  layout of its own holding only that nudge: All plates' other moves and its Center are gone from hostile plates.
- After: Hostile's own layout starts as a copy of All plates', the nudge on top. Unticking Own layout keeps it
  (unused); ticking again brings it back. Changing a kind while it isn't ticked starts from All plates' again, as
  it shows.

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased.
- Other features, other addons: none read a kind's layout but PlateLayout.lua (ns.PlateLayoutFor).
- Tests that encode it: none; Tools/offline/platelayoutpage.lua edits All plates only.

## States (the matrix)
All plates' layout empty / level box 10 right with Balanced; on Hostile: crowd control nudged with the arrow key,
or Own layout ticked.
Test: Tools/offline/platelayoutkindmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-kindcopy | all=levelRight action=nudge | own=true level=0 crowd=1 center=bar | own=true level=10 crowd=1 center=balanced |
| platelayout-kindcopy | all=levelRight action=tick | own=true level=0 crowd=0 center=bar | own=true level=10 crowd=0 center=balanced |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab only, unreleased. Pinned offline on the real page (the arrow key and the Own layout tick).
Not offline: the page's look as you switch kinds (the in-game run).
