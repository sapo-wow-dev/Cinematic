# Rules: you dead asked when you die or come back, not every working out (fix card)
Fix: with a rule naming dead, the rule facts asked UnitIsDeadOrGhost("player") on every full working out (every 0.1 s, 0.5 s idle), though the game announces dying, releasing and coming back
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the dead entry (ns.AddEventFact), ns.RuleFacts (the dead line)
Clients: both
Base: 58ef7b6

## Before / after
- Before: dead asked UnitIsDeadOrGhost("player") each full working out while a rule named it.
- After: asked once, then after PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST or a loading screen (and for 0.5 s after each). Same word; a secret answer still counts as alive.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UnitIsDeadOrGhost`, read every hit.)
- Players: rules naming dead. The death cinematic, the corpse cards and the target words read UnitIsDeadOrGhost themselves: untouched.
- Other features: none read facts.dead but the rules.
- Other addons: none.
- Tests that encode it: the offline tests stubbing UnitIsDeadOrGhost (mostly for the target or mouse): healauras, hoverwords, unitwords, valuewords, talknames, prdkill, shoulderghostwolf, corpse, statewords pass; hovermatrix, manavisionloopmatrix, zonecardmatrix 0 cells changed.

## States (the matrix)
The states: dead or not, nothing new or flipped with PLAYER_DEAD (dying) or PLAYER_UNGHOST (back). A rule names dead in every cell. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever dead
Test: Tools/offline/eventfactsmatrix.lua retail dead

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-dead | word=dead start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-dead | word=dead start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-dead | word=dead start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-dead | word=dead start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the three events cover dying, releasing (a ghost is still dead), resurrecting and reaching your corpse. Not proven offline: a resurrection accepted during a loading screen (PLAYER_ENTERING_WORLD asks again). For the test skill's run: die, release, run back with a rule naming dead.
