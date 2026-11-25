# Rules: resting asked when the game says it changed, not every working out (fix card)
Fix: with a rule naming resting, the rule facts asked IsResting on every full working out (every 0.1 s, 0.5 s idle), though the game sends PLAYER_UPDATE_RESTING for every change
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the resting entry (ns.AddEventFact), ns.RuleFacts (the resting line)
Clients: both
Base: baabf86

## Before / after
- Before: resting asked IsResting each full working out while a rule named it.
- After: asked once, then after PLAYER_UPDATE_RESTING or a loading screen (and for 0.5 s after each). Same word.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsResting`, read every hit.)
- Players: rules naming resting. The place (ns.GetPlaceType's inn, fix card 2026-11-25-event-fact-place.md) and the camp cards read IsResting themselves: untouched.
- Other features: none read facts.resting but the rules.
- Other addons: none.
- Tests that encode it: Tools/offline/rulewords.lua plays the Rule Words kit test on the stand-in: its inn step flipped IsResting with no event; it now sends PLAYER_UPDATE_RESTING as the game does (checks unchanged).

## States (the matrix)
The states: resting or not, nothing new or flipped with PLAYER_UPDATE_RESTING. A rule names resting in every cell. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever resting
Test: Tools/offline/eventfactsmatrix.lua retail resting

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-resting | word=resting start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-resting | word=resting start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-resting | word=resting start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-resting | word=resting start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/rulewords.lua | resting step (and the steps after it) | the inn flipped IsResting with no event: passed by polling | the stand-in sends PLAYER_UPDATE_RESTING as the game does: passes; with no event the resting step fails | the user, 2026-11-25: "OK, commit" |

## Risk
low: PLAYER_UPDATE_RESTING comes stepping into and out of an inn or a capital. For the test skill's run: the Rule Words kit test's inn step.
