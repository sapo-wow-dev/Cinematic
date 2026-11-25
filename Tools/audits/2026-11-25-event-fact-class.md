# Rules: class asked once, not every working out (fix card)
Fix: the rule facts asked the game for your class on every full working out (every 0.1 s, 0.5 s idle) while a rule named a class word, though it never changes in a session
Found by: audit 2026-11-25 (event-driven rule facts, the user: "this seems like bad design")
Code: Frames.lua: ns.eventFacts, ns.AddEventFact, ns.EventFactChanged, ns.ReadEventFacts (new), the class entry, ns.RuleFacts (the class line)
Clients: both
Base: 88e355c

## Before / after
- Before: with a rule naming warrior, mage or another class, UnitClass("player") was asked on every full working out. With none, it was still asked once a pass (only the word skipped). Unnamed class words were nil.
- After: your class is asked once (and after each loading screen, PLAYER_ENTERING_WORLD), only while a rule names a class word; the words read the same. Unnamed class words read false instead of nil (a rule reads nil and false alike). The new ns.AddEventFact is the shared way for the next fixes (role, group, flagged, afk, resting, dead, mounted, casting): a fact asked after its events, again for 0.5 s after each, false while no rule names it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UnitClass RuleFacts`, read every hit.)
- Players: rules naming a class (built-in profiles: none name one). Same answers.
- Other features: RuleAxes.lua (another session, uncommitted) reads UnitClass for its own axis: untouched. Frames.lua's unit parts loop walks every fact for changes (nil to false once: one extra apply at most).
- Other addons: none.
- Tests that encode it: Tools/offline/statewords.lua and valuewords.lua stub UnitClass once at load (unchanged answer); Tools/offline/factswords.lua (passes).

## States (the matrix)
The states: your class (warrior or not), nothing new or a later working out ("flip": class can't change, so as none). A rule names the class word in every cell (with none, it's false and never asked, factswords.lua). Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever class
Test: Tools/offline/eventfactsmatrix.lua retail class

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-class | word=class start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-class | word=class start=off change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-class | word=class start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-class | word=class start=on change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: class can't change in a session; asked again after every loading screen. What isn't proven offline: that UnitClass answers at the first working out after login on both clients (it does at ADDON_LOADED in every test so far).
