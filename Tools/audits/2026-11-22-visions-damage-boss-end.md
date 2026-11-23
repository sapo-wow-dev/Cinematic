# Damage Vision: a boss's end with a secret name or result (fix card)
Fix: ENCOUNTER_END's name and result can come secret under the game's addon limits (retail); Damage Vision compared
the result and handed the name on to the boss recap as it was (a compare on a secret errors in the game).
Found by: audit 2026-11-22; fixed in bdb2e1d (retroactive card, 2026-11-23)
Code: Visions/DamageVision.lua: the events' OnEvent (ENCOUNTER_START, ENCOUNTER_END), Queue()
Clients: both
Base: bdb2e1d^

## Before / after
- Before: a boss won with its name secret had the recap handed the secret name (titled with it, or an error on the
  way); a secret result was compared to 1 (a Lua error in the game).
- After: a secret name gives a recap titled Boss (not looked up by name); a secret result queues no recap.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ENCOUNTER_END damageVisionRecapBoss`)
- Players: Damage Vision with the Boss recap on (retail raids/dungeons under addon limits); plain names and results
  (Forever, most of retail) unchanged.
- Other features: Recap and Combat Vision read ENCOUNTER_END the same guarded way (the comment says); RunPending looks
  the session up by name when it has one.
- Other addons: none.
- Tests that encode it: Tools/offline/fightsfades.lua check 6 (kept).

## States (the matrix)
the boss's name (plain / secret / missing) x the result (win / wipe / secret) x the Boss recap row (on / off), per
client. 18 cells per client. (Secrets are plain tables here: the old code's compare can't error, so the cells show
only what it handed on.)
Test: Tools/offline/bossendmatrix.lua forever
Test: Tools/offline/bossendmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| damage-boss-end | name=secret result=win recapRow=on | recap=boss name=secret | recap=boss name=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: guards on two values. Not proven offline: the game's error on comparing a secret (the old result=secret
cells error in game, not here), ENCOUNTER_START's secret name (kept as true: not seen by any cell's outcome).

## Open
- user's call: a won boss whose result comes secret gets no recap (result=secret result: recap=none). Pinned so (the
  commit's choice: can't tell a win from a wipe); a recap titled Boss on every secret end would be the other way.
