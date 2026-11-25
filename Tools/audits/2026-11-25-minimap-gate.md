# Minimap: Questie pins and the reveals off with Minimap's Show or the HUD off (fix card)
Fix: with Minimap's Show tab or the HUD's General off, the Minimap page's Questie pins kept being drawn and its node, cursor and quest reveals kept sweeping the minimap (they read the page's own switch alone)
Found by: audit 2026-11-25 (gating, finding F7: raw reads)
Code: Support/QuestieMinimap.lua: ns.QuestieMinimapOn; UI/NodeSweep.lua: AnyReveal, cursor.On, QuestReveal
Clients: both (Questie: classic clients)
Base: baabf86

## Before / after
- Before: Minimap page on, its Show tab (or the whole HUD) off: the page greys, but Questie's pins stay
  on our minimap and the reveals still sweep it.
- After: off with any of the three switches off; on again with all on.

## Who relies on the old behavior
(`python -I Tools/audit.py refs QuestieMinimapOn minimapQuestie minimapNodesByCursor minimapRevealNodes`)
- Players: those with Show or the HUD off and these ticked (greyed for them).
- Other features: the minimap's reveal holds (NodeSweep's own callers), the Questie pins' refresh.
- Other addons: Questie: its own minimap pins are untouched.
- Tests that encode it: questiegatematrix (Questie loaded or not, all switches on: unchanged), mappin.lua.

## States (the matrix)
The feature, the Minimap page, Minimap's Show tab, the HUD's General.
Test: Tools/offline/minimapgatematrix.lua forever
Test: Tools/offline/minimapgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| minimap-gate | page=on show=off | on | off |
| minimap-gate | page=on hud=off | on | off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more walk up the switches (ns.PageOn) where the page's own was read. Questie's pins already on
the minimap when Show goes off go with its next refresh (its own pass), not proven offline. Not done:
Core.lua's frameKeysReset (see the report: with the Frames tab off, frames forced by their keys are still
forced, so skipping the login reset would keep them forced with no key to undo).
