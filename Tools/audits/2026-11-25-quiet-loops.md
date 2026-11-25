# Visions: four loops and event handlers rest while their page is off (fix card)
Fix: with Quest Vision off, its item button refreshed every 2 s and its target frame icon twice a second
(kept alive by their raw ticks); with Damage Vision off each fight's edge woke its display; with Roll
Vision off each roll scanned the loot history, hooked the roll frames and set a timer, and each loot event
logged "Roll Vision is off"
Found by: audit 2026-11-25 (gating, finding D22 in 2026-11-25-gating-findings.md)
Code: Visions/QuestItemButton.lua: its FeatureLoop, ns.RefreshQuestItemButton (wakes it); Visions/QuestMobs.lua:
targetWatcher's FeatureLoop, ns.RefreshTargetQuestIcon (wakes it); Visions/DamageVision.lua: the events
frame's last Wake; Visions/RollWindow.lua: the loot watcher's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: the loops above ran while their tick was saved on, whatever Quest Vision's page (or Allow outside
  CineMode) said; Damage Vision's display was placed, dressed and shown at every fight start and end,
  encounter and loading screen with its page off; Roll Vision did the roll-start work and logged each loot
  event with its page off.
- After: each only while its part can show (the tick through ns.QuestVisionSetting; Damage Vision's
  ns.Setting, a test or the display still up; Roll Vision's Enabled), with no log line while off. The
  Quest Vision refreshes (its page switch in Options.lua, ns.RefreshOutsideCine) wake their loops at once.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshQuestItemButton RefreshTargetQuestIcon questItemButton targetQuestIcon damageVision rollWindow`)
- Players: nothing on screen: each refresh already hid with its setting off (ns.QuestVisionSetting there);
  Damage Vision's update hid it when not Allowed; Roll Vision's window only opens when Enabled.
- Other features: Questie's item button / target icon support (ns.QuestieItemButton, QuestieTargetIcon)
  still asked on each refresh while on. A button or icon still up when switched off keeps its loop till
  it's hidden, as before.
- Other addons: an addon taking over the rolls is now noticed from the first roll after Roll Vision comes on.
- Tests that encode it: none on these loops.

## States (the matrix)
The part, its page on or off, its own tick (the Quest Vision parts); CineMode on.
Test: Tools/offline/quietloopsmatrix.lua forever
Test: Tools/offline/quietloopsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| quiet-loops | part=itemButton page=off tick=on | work | none |
| quiet-loops | part=targetIcon page=off tick=on | work | none |
| quiet-loops | part=damage page=off | work | none |
| quiet-loops | part=roll page=off | work | none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: each gate is the one its feature's own show check already used. Not proven offline: a real roll with
another addon's roll frames (takenOver), the item button's zone ability hooks, Damage Vision's display at a
real fight's end.
