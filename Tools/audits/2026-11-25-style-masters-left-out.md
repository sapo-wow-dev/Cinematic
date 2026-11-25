# Core: the Overrides tab and Visions Style keep Enable Style as their master with Style left out (fix card)
Fix: with Style left out, styleOverrides and visionsStyle lost their master (set inside Style's part), so they read as on
Found by: the gating in-game test's offline run (Dev/GatingTest.lua step 1), 2026-11-25, after gate-tree-shape (F2)
Code: Core.lua: PAGE_SWITCH styleGeneral list
Clients: both
Base: 82722d9

## Before / after
- Before: Load Style unticked: ns.Setting / ns.PageOn read the Style Overrides tab and the Visions Style page
  as on (their master, Enable Style, is set by Style's own files, which don't run). Nothing of Style runs,
  but code outside Style asking these switches got "on".
- After: both sit under Enable Style in Core's list, whichever parts load; with Style left out they read off.

## Who relies on the old behavior
(`python -I Tools/audit.py refs styleOverrides visionsStyle`)
- Players: none; with Style loaded the master is the same as before.
- Other features: ns.StyleOverride (already a stand-in with Style out), ns.StyleLook's Visions borders
  (db.visionsStyle, read only with Style on).
- Tests that encode it: gatetreematrix.lua (extended here with the two keys; no pin edited).

## States (the matrix)
Each part loaded or left out, each moved switch; the client.
Test: Tools/offline/gatetreematrix.lua forever
Test: Tools/offline/gatetreematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| gate-tree-shape | load=style switch=styleOverrides | none | styleGeneral |
| gate-tree-shape | load=style switch=visionsStyle | none | styleGeneral |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: two keys added to a master list they already had while Style is loaded.
