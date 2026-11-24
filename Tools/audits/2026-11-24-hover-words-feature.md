# Rules: the Mouse over words arrive (fix card, for the feature)
Fix: not a fix: e24b0e1 added the mouse words (hover, hoverdead...), so before it every mouse word read false; this card declares those cells, so the release check (every card's matrices vs the last tag) can tell them from a broken neighbor
Found by: release review 2026-11-24 (v2.1.32)
Code: Frames.lua: ns.HoverWords, ns.CompileRule
Clients: both
Base: e24b0e1^

## Before / after
- Before (v2.1.31): no mouse words; a rule naming one didn't read.
- After: the mouse words read the unit under the mouse (gated since 2026-11-24-hover-words-gate.md: only with a rule naming one or the rule editor up).

## Who relies on the old behavior
- Nobody: the words were new.

## States (the matrix)
As 2026-11-24-hover-words-gate.md.
Test: Tools/offline/hovermatrix.lua forever
Test: Tools/offline/hovermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| hover-words | unit=mob guid=plain | hover=false dead=false reads=0 | * |
| hover-words | unit=mob guid=secret | hover=false dead=false reads=0 | * |
| hover-words | unit=corpse guid=plain | hover=false dead=false reads=0 | * |
| hover-words | unit=corpse guid=secret | hover=false dead=false reads=0 | * |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a new feature, off unless a rule names a mouse word. In game: proven on Forever (mousewords 26/0, 2026-11-24); not in a fight or an instance (ledger tooltip-no-wait Q2), not on retail.
