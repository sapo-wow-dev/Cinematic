# Cards: the explore count is built only when a card or the bars read it (fix card)
Fix: every login (and the first achievement step done) walked the game's whole achievement list for the
explore count, with Cards, Discovered, Explore progress and Achievement step all off
Found by: audit 2026-11-25 (gating, finding D21 in 2026-11-25-gating-findings.md)
Code: Visions/CardMoments.lua: the login timer, explore.Wanted (new), progress.StepDone
Clients: both
Base: baabf86

## Before / after
- Before: 10 s after login, explore.Index started its walk of every achievement category (spread over
  frames, 4 ms each) whatever was ticked; CRITERIA_EARNED built it too before looking at any card.
- After: the login's early build only with Discovered, Explore progress or Achievement step on, or the
  Letterbox's bars on a new place; an achievement step builds it only with Almost there, Explore progress
  or Achievement step on. Anything else that reads it (the zone card with Discovered, PlaceExplored) still
  builds it on first use, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlaceExplored explore.Index letterboxOnDiscover`)
- Players: with those cards on, the same as before. Turning one on later: the count builds on its first use
  (as it always did when asked before the login's 10 s).
- Other features: ZoneCard.lua asks ns.PlaceExplored only with Discovered on (built then at login);
  Discovered's Wanted (card or bars) the same; the step and almost cards unchanged with them on.
- Other addons: none.
- Tests that encode it: discoveredline.lua, discoversamenamematrix.lua (run, unchanged).

## States (the matrix)
Which reader is on (none, Discovered, Explore progress, Achievement step, Almost there, the bars); the
login's timer or an achievement step.
Test: Tools/offline/exploreindexmatrix.lua forever
Test: Tools/offline/exploreindexmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| explore-index | reader=none | built=yes | built=no |
| explore-index | reader=almost when=login | built=yes | built=no |
| explore-index | reader=discover when=criteria | built=yes | built=no |
| explore-index | reader=letterbox when=criteria | built=yes | built=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the index was always lazy; only its early start is skipped. Not proven in game: a first zone change
right after turning Discovered on (the count builds over a few frames then, its first answer may be
"not in it", as before the 10 s at login).
