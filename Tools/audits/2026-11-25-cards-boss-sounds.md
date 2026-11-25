# Cards: the Boss event's Sounds tab off silences its kill and wipe sounds (fix card)
Fix: with the Boss event's Sounds tab switched off, a boss kill or wipe still played its sound
Found by: audit 2026-11-25 (gating, finding C19 in 2026-11-25-gating-findings.md)
Code: Visions/CombatVision.lua: the watcher's ENCOUNTER_END branch
Clients: both
Base: baabf86

## Before / after
- Before: Cards on, the Boss row ticked, its Sounds tab switched off: the boss card makes no sound, but the
  kill (or wipe) sound as the fight ends still plays.
- After: the Sounds tab off silences those too; on, they play as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlayCombatCueSound CardPartOff`)
- Players: those who switched the Boss Sounds tab off wanted it silent; with it on (the default) nothing
  changes.
- Other features: Cards.lua's Show already asks the Sounds tab for every card's own sound.
- Other addons: none.
- Tests that encode it: none on the kill/wipe sound.

## States (the matrix)
The fight's result (win, wipe), the Boss row ticked or not, its Settings tab and its Sounds tab on or off.
Test: Tools/offline/bosssoundsmatrix.lua forever
Test: Tools/offline/bosssoundsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| boss-sounds | result=win row=on settingsTab=on soundsTab=off | sound=kill | sound=none |
| boss-sounds | result=wipe row=on settingsTab=on soundsTab=off | sound=wipe | sound=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more condition, true unless the Boss Sounds tab is off. Not proven in game: the sound itself at a
real boss's end (the matrix stubs ns.PlayCombatCueSound).
