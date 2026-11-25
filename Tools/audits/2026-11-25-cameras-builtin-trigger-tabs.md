# Cameras: our built-in triggers obey their Starts, Timing and Scenes tabs (fix card)
Fix: right-clicking off a built-in trigger's Starts, Timing or Scenes tab on the Triggers page did nothing; only your own triggers read those tabs
Found by: audit 2026-11-25 (gating, finding C5 in 2026-11-25-gating-findings.md)
Code: Camera/Triggers.lua: Parts, Gate
Clients: both
Base: baabf86

## Before / after
- Before: one of ours (Stand still, Dance, Hearthstone...) on the Triggers page: its Starts or Scenes
  tab off, it still starts its scene; its Timing tab off, its wait, cooldown and chance still apply.
- After: as your own triggers: Starts or Scenes off, it never starts (one playing stops; the Triggers
  log says "Its Starts or Scenes tab is off"); Timing off, no wait, cooldown or chance. Ends off
  changes nothing (ours end as their thing does).

## Who relies on the old behavior
(`python -I Tools/audit.py refs PickTrigger tabOn:Trigger`)
- Players: only those who switched one of these tabs off on one of ours (they're on by default).
- Other features: CurrentEvent's pick (Camera.lua) and the Why window's Cameras tab (triggerPickSeen):
  a held one now shows as held. Your own triggers (CustomTriggers.lua): unchanged.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
None of its tabs off, or Starts, Ends, Timing or Scenes off; its wait 0 or 5 sec.
Test: Tools/offline/builtintabsmatrix.lua forever
Test: Tools/offline/builtintabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| builtin-trigger-tabs | off=starts wait=0 | Still | none |
| builtin-trigger-tabs | off=scenes wait=0 | Still | none |
| builtin-trigger-tabs | off=timing wait=5 | none | Still |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with a tab switched off. Not proven offline: the tab's right-click in game (its key is
tabOn:Trigger:<library id>:<part>, as the page makes it).
