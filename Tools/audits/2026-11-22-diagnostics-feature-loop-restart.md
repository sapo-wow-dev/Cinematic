# Diagnostics: a feature loop its breaker turned off, the feature started over (fix card)
Fix: ns.FeatureLoop's protected wrapper was made once, so after 5 errors in 3 s it was dead for the session, even
with its feature switched off and on again (ns.SetOnUpdate's loops come back as they're set again).
Found by: audit 2026-11-22; fixed in 7c3e0c1 (retroactive card, 2026-11-23)
Code: Diagnostics.lua: Protect() (the state argument), SyncFeatureLoop() (dead reset as it turns on), ns.FeatureLoop
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: a feature whose update loop kept failing (a Vision, a Style refresh) stopped till a /reload, whatever the
  player did on its page.
- After: switching the feature off and on starts its loop again (one line in /cine log); still failing, the breaker
  turns it off again after 5 errors. Left on, it stays off (no error spam).

## Who relies on the old behavior
(`python -I Tools/audit.py refs FeatureLoop SyncFeatureLoops`)
- Players: nobody wants a feature dead till a reload; the breaker still stops spam.
- Other features: every ns.FeatureLoop user (Visions, Styles, plates), ns.WakeFeatureLoop / RunFeatureLoopSoon,
  /cine debug loops (ns.featureLoopsForced: every loop wanted, so a dead one restarts as it's forced on).
- Other addons: none.
- Tests that encode it: Tools/offline/heldpartsletgo.lua check 2 (kept).

## States (the matrix)
the loop (every frame / on a 1 s timer) x the breaker (tripped / no) x then (feature off and on / left on / off) x
what it runs (fixed / still failing), per client. 24 cells per client. Error reports stubbed (the addon's own
repeat check would suspend it).
Test: Tools/offline/featureloopmatrix.lua forever
Test: Tools/offline/featureloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| featureloop-breaker | broke=tripped then=offon fixed=yes | runs=0 | runs=8 |
| featureloop-breaker | broke=tripped then=offon fixed=no | runs=0 | runs=5 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: the dead flag reset only as a loop turns on. Not proven offline: the addon-wide safety stop (ReportError's
repeat check, ns.Suspend) that a real repeating error also trips, and /cine resume after it.

## Open
- user's call: tripped, with the feature left on (broke=tripped then=stayon), the loop stays off till the feature is
  switched off and on (or a reload). Pinned so (no error spam); /cine resume bringing it back too is not tested here.
