# Rules: in a group asked when the roster changes, not every working out (fix card)
Fix: the rule facts asked IsInGroup on every full working out (every 0.1 s, 0.5 s idle) for every player (group is always worked out: plate When ticks read it), though the game announces every roster change
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the group entry (ns.AddEventFact), entry.key in ns.ReadEventFacts (new), ns.RuleFacts (the group line)
Clients: both
Base: 6a8f4d2

## Before / after
- Before: facts.group = ns.InGroup() each full working out.
- After: asked once, then after GROUP_ROSTER_UPDATE, GROUP_JOINED, GROUP_LEFT or a loading screen (and for 0.5 s after each), and when /cine debug group changes ns.fakeGroup (entry.key: a Lua value compared each pass, no game call). Same word.

## Who relies on the old behavior
(`python -I Tools/audit.py refs InGroup fakeGroup`, read every hit.)
- Players: rules and plate rows' When Group tick (MARK_WHEN_WORDS): same answers. The grids' group ticks read ns.InGroup themselves: untouched.
- Other features: /cine debug group (ns.fakeGroup): pinned (change=fake).
- Other addons: none.
- Tests that encode it: none read facts.group but the rule tests (pass).

## States (the matrix)
The states: in a group or not, nothing new, the roster changed with GROUP_ROSTER_UPDATE, or /cine debug group party (no game event). Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever group
Test: Tools/offline/eventfactsmatrix.lua retail group

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-group | word=group start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-group | word=group start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-group | word=group start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-group | word=group start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: GROUP_ROSTER_UPDATE comes for every join, leave and conversion on both clients. Not proven offline: a group disbanded during a loading screen (PLAYER_ENTERING_WORLD asks again). For the test skill's run: join and leave a party with a rule naming group.
