# Vitals Vision: health events don't wake it while its Health tab can't show (fix card)
Fix: with Vitals Vision's page or its Health tab off, every health change, max health change and fight edge
still woke its update and ran it till it settled
Found by: audit 2026-11-25 (gating, finding D18 in 2026-11-25-gating-findings.md)
Code: Atmosphere/LowHealth.lua: the events frame's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: Vitals off (or its Health tab off): each UNIT_HEALTH, UNIT_MAXHEALTH, UNIT_COMBAT heal and
  fight start or end showed the driver, so a full Update ran (theme picked, health read, layers cleared)
  at least once per event, every frame in a fight with secret health.
- After: those events wake it only with the Health tab on (with its page, and Allow outside CineMode as
  it says), or the page's Test or the welcome window's quick look running. Switching it off live still
  settles it: ns.RefreshLowHealth wakes it itself.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshLowHealth TestLowHealth VITALS_HEALTH_TAB`)
- Players: nothing on screen: Update's Wanted already showed nothing with the tab off.
- Other features: Mana Vision has its own driver and events (ManaVision.lua): unchanged. The test and the
  quick look wake it themselves and are kept as waking reasons too. The health guess (healthGuess) for the
  sound at Full is only used while the tab's on, and is read again by the first Update once it's back.
- Other addons: none.
- Tests that encode it: manavisionloopmatrix.lua, manavision.lua (Mana's loop): run, unchanged.

## States (the matrix)
The page, its Health tab, the Test running or not; the event (health, max health, a fight starting).
Test: Tools/offline/vitalswakematrix.lua forever
Test: Tools/offline/vitalswakematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| vitals-wake | page=off test=no | woke=yes | woke=no |
| vitals-wake | page=on tab=off test=no | woke=yes | woke=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one condition before Wake. Not proven offline: CineMode coming on with Allow outside CineMode
unticked while hurt and no health event after (the vision shows at the next health event, as after the
driver had slept before), secret health in a real fight.
