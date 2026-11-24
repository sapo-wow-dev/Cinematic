# Rules: mouse words read only when a rule uses one (fix card)
Fix: every player paid for the mouse words each frame, even with no rule naming one; in instances (secret GUID) the full working out ran every frame, and the secret GUID was tested before issecretvalue
Found by: release review 2026-11-24 (v2.1.32)
Code: Frames.lua: ns.HoverWords, ns.CompileRule
Clients: both
Base: e24b0e1

## Before / after
- Before: with the mouse on a unit, ns.HoverWords worked out the mouse words for every player, rule or not; each new unit under the mouse made every row's rule read again (ns.factsGen). In an instance, where the GUID is secret, the whole working out (GetMouseFoci, the parent walk, the kind's row) ran every frame, and `UnitGUID("mouseover") or nil` and `guid == nil` touched the secret value.
- After: nothing is read, and every mouse word is false, until a rule naming one compiles (kept till a /reload) or while the rule editor is up (its lit dots). Then as before. The GUID is checked with issecretvalue before anything else touches it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs HoverWords hoverState`)
- Players: only rules naming a mouse word read these facts (new in e24b0e1, not yet released): unchanged for them.
- Other features: the rule editor's dots (GridRows.lua:725, RuleFactsFor): the editor up keeps them read. Why.lua reads no mouse word. MARK_WHEN_WORDS has none.
- Other addons: none.
- Tests that encode it: Tools/offline/hoverwords.lua checks 1-9 read the facts with no rule compiled (now one compiles first, check 0 pins "no rule: nothing read"); Dev/MouseWordsTest.lua sets the Tooltips rule then reads facts (now compiles it at once).

## States (the matrix)
A rule naming a mouse word or none, the rule editor up or down, nothing / a living mob / a corpse under the mouse, its GUID plain or secret. Each cell: hover, hoverdead and the unit reads in three frames.
Test: Tools/offline/hovermatrix.lua forever
Test: Tools/offline/hovermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| hover-words | rule=none editor=down unit=mob guid=plain | hover=true dead=false reads=2 | hover=false dead=false reads=0 |
| hover-words | rule=none editor=down unit=mob guid=secret | hover=true dead=false reads=6 | hover=false dead=false reads=0 |
| hover-words | rule=none editor=down unit=corpse guid=plain | hover=true dead=true reads=2 | hover=false dead=false reads=0 |
| hover-words | rule=none editor=down unit=corpse guid=secret | hover=true dead=true reads=6 | hover=false dead=false reads=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/hoverwords.lua | checks 1-9 (facts with no rule compiled) | read with no rule | a hover rule compiled first; new check 0: no rule = nothing read | the user, 2026-11-24: "Yes, OK it" |

## Risk
low: only players with a rule naming a mouse word use these facts, and a rule compiles the first time its row is read (one frame late at most after a /reload). Sticky: a mouse word typed in the editor and removed keeps reading till a /reload (as before this fix). Not proven offline: the real rule editor's IsShown in game; a secret GUID in a real instance (ledger tooltip-no-wait Q2).
