# Diagnostics: an error in a feature loop's wanted() reported, not swallowed (fix card)
Fix: SyncFeatureLoop ran a loop's wanted() in a pcall and took an error as "keep running", with no report: a broken
gate never showed in /cine log, BugSack or the offline checks (the prerelease audit's planted error in WeatherFX's
Wanted() went unseen everywhere).
Found by: audit 2026-11-23 (prerelease audit)
Code: Diagnostics.lua: SyncFeatureLoop() (xpcall + GateHandler, loop.gateFailed)
Clients: both
Base: d580b7d

## Before / after
- Before: a feature whose on/off check errored kept its loop running every frame (a cost, and the feature as if on)
  with nothing in /cine log; the player and we never knew.
- After: the same loop still runs (nothing else changes), and the error is logged and passed on once, like any other
  caught error ("hit a Lua error. Type /cine log"). Once wanted() works again it's quiet; failing again later reports
  again (the addon's own repeat check counts it as one message).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SyncFeatureLoop FeatureLoop`, 64 code hits: every ns.FeatureLoop user.)
- Players: none rely on a hidden error. A wanted() that errors today for some player would now show one error line
  once per session (by design: that's a real bug to fix).
- Other features: every ns.FeatureLoop caller; their wanted() as before. Kept running as before (want = true).
  /cine debug loops (featureLoopsForced) as before.
- Other addons: none.
- Tests that encode it: Tools/offline/featureloopmatrix.lua (2026-11-22 card; its pins kept, a gate dimension added),
  heldpartsletgo.lua (kept).

## States (the matrix)
The 2026-11-22 matrix (loop x broke x then x fixed) with wanted() working or failing (gate=ok/fails): 48 cells per
client. Error reports counted by a stub.
Test: Tools/offline/featureloopmatrix.lua forever
Test: Tools/offline/featureloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| featureloop-breaker | gate=fails broke=no fixed=yes | runs=8 | runs=8 reported=1 |
| featureloop-breaker | gate=fails broke=no fixed=no | runs=5 | runs=5 reported=1 |
| featureloop-breaker | gate=fails broke=tripped | runs=0 | runs=0 reported=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a loop whose wanted() errors, and then only one error line more. Pinned: every gate=ok cell unchanged, both
clients. Not proven offline: whether any shipped wanted() errors in game today (it would now show in /cine log).
