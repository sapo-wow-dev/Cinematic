# Cooldown Manager: a bar's tab off, or the page, leaves its icons as the game has them (fix card)
Fix: a bar's tab off still centered its icons and kept its keybinds, numbers and Use the spell's cooldown; the Buffs tab off still drew rings and stack counts; the page off kept the rings' and stacks' loops and events running, and the bars' own layout hooks centered them again
Found by: audit 2026-11-25 (gating, findings C8 and D13 in 2026-11-25-gating-findings.md)
Code: Frames.lua: ns.CooldownGroupCentered, ns.CooldownRowSetting, SyncSwitches; UI/CooldownRing.lua: On, ns.ApplyCooldownRing; UI/CooldownStacks.lua: On, Update, the watcher's OnEvent, ns.ApplyCooldownStacks; UI/CooldownGrid.lua: LookGet (the page's own read, own false)
Clients: both
Base: baabf86

## Before / after
- Before: right-click the Essential tab off on the Cooldown Manager page: its icons still slid together
  (Close the gaps), kept the keybind text and the countdown numbers the row set. The Buffs tab off: rings
  and stack counts still drawn. The whole page off: the rings' watch and its UNIT_AURA / absorb / cast
  events kept running, the stack counter kept counting casts four times a second, and the next time the
  game laid a bar out its icons were centered again.
- After: a tab off, that bar's icons are the game's own (no centering, its own keybind-less icons,
  numbers as the game sets them, the buff shown). Buffs tab off: no rings; Buffs and Bars tabs off: no
  stack counts. The page off: none of it, and the rings' and stacks' watchers stop, started again as the
  page or a tab comes back (the switches' refresh, ns.SyncSwitches, each frames pass).

## Who relies on the old behavior
(`python -I Tools/audit.py refs CooldownGroupCentered CooldownRowSetting ApplyCooldownStacks ApplyCooldownRing`)
- Players: none want a switched-off tab's look kept; the stacks comment ("keeps counting while off") was
  the old design, the user's page off = all off rule wins (decided in the audit).
- Other features: the page's grid (UI/CooldownGrid.lua LookGet) now reads the set value (own false), so
  its cells show what's set with the tab off, as before. Keybinds, numbers, notBuff/both (CooldownBoth),
  the ring's StyleOf all read CooldownRowSetting: off with the tab now.
- Other addons: EllesmereUI's cooldown manager (FeatureYieldedTo "cooldownCenter"): unchanged.
- Tests that encode it: cdmring.lua, cooldowngrid.lua, cdmringgroupmatrix, cdmringsizematrix,
  cdmringlocalematrix, cdmpandemicmatrix, cooldownlinesmatrix, cdmmissingsecretmatrix: all PASS, both
  clients. Dev/CdmRingTest.lua and Dev/DotNumbersTest.lua run with the page on.

## States (the matrix)
The page's switch on or off, the bars' tabs on or off (all of them), with every extra set to start, after
the switches' refresh. (HUD and its section on.)
Test: Tools/offline/cdmgatematrix.lua forever
Test: Tools/offline/cdmgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdm-gate | page=on tab=off | center=true keys=true nums=show notBuff=true ring=run stacks=run | center=false keys=false nums=untouched notBuff=false ring=stop stacks=stop |
| cdm-gate | page=off | center=true keys=true nums=show notBuff=true ring=run stacks=run | center=false keys=false nums=untouched notBuff=false ring=stop stacks=stop |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: every gate is true with the page and the tab on (all players who never right-click a CDM tab).
Page-off cells: keybinds and numbers were already let go by their own page checks; now the row values
read off too. Not proven offline: real icons sliding back on a tab flip (the once-a-second pass puts them
back), the stack counts on Forever's Arcane Blast with Bars on and Buffs off.
