# Rules: casting asked as your casts start and stop, not every working out (fix card)
Fix: with a rule naming casting, the rule facts asked UnitCastingInfo and UnitChannelInfo on every full working out (every 0.1 s, 0.5 s idle), though the game sends an event as each of your casts starts, stops or is cut short
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the casting entry (ns.AddEventFact), ns.RuleFacts (the casting line)
Clients: both
Base: 568b1b6

## Before / after
- Before: casting asked UnitCastingInfo / UnitChannelInfo each full working out while a rule named it.
- After: asked once, then after the player's UNIT_SPELLCAST_START, STOP, CHANNEL_START, CHANNEL_STOP, INTERRUPTED, FAILED, SUCCEEDED, EMPOWER_START, EMPOWER_STOP or a loading screen (and for 0.5 s after each). Same word; secret in a fight still reads false.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UnitCastingInfo casting`, read every hit.)
- Players: rules naming casting or cast. ns.CastingRuleOn (a cast a rule names counts as a fight for the fades) and the unit parts loop read UnitCastingInfo themselves, then the facts after the cast's event: same.
- Other features: the cameras' casting pause reads the game itself: untouched.
- Other addons: none.
- Tests that encode it: loopsoff, noaddons, gameplate, factswords pass; camerasoffmatrix 0 cells changed with this fix alone (its 10 pin FAILs are on HEAD already: another session's camera work in the tree).

## States (the matrix)
The states: casting or not, nothing new or a cast started (UNIT_SPELLCAST_START) or stopped (UNIT_SPELLCAST_STOP). A rule names casting in every cell. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever casting
Test: Tools/offline/eventfactsmatrix.lua retail casting

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-casting | word=casting start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-casting | word=casting start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-casting | word=casting start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-casting | word=casting start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: every cast sends a start and an end event on both clients (the fight's secret answers read false as before). Not proven offline: an instant cast (SUCCEEDED with no START) and an empowered cast on retail. For the test skill's run: cast and channel with a rule naming casting.
