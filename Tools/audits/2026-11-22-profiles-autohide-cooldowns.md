# Profiles: Auto-Hide UI keeps your Cooldown Manager (fix card, retroactive)
Fix: v2.1.24 turned the Cooldown Manager page off in Auto-Hide UI's base. A copy of Auto-Hide UI saved on v2.1.23
held nothing for it (it was on in the base then), so switching back to it, or its Reset, turned the page off.
Found by: code audit 2026-11-22; fixed in bdb2e1d (card written after, 2026-11-23)
Code: Migrations.lua: the autoHideCooldownsV1 step (saved copies and reset points of Auto-Hide UI)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: you'd used Auto-Hide UI on v2.1.23 with the Cooldown Manager page on (as it came). After the update,
  switching back to Auto-Hide UI from another profile, or pressing Reset with a reset point saved on v2.1.23,
  turned the page off: your cooldown bars were no longer faded or ruled by Cinematic.
- After: the saved copy and the reset point keep it on, once. A first pick of Auto-Hide UI (never saved) and a
  Reset with no reset point give the built-in's off, as for a new player. Turned off yourself: stays off.
- Never affected: being on Auto-Hide UI at the update (the live switch is yours, saved at the next switch).

## Who relies on the old behavior
(`python -I Tools/audit.py refs autoHideCooldownsV1 handleCooldowns`)
- Players: Auto-Hide UI users from v2.1.23 with a saved copy or reset point; nobody relies on the page going off.
- Other features: Profiles.lua Load / ResetProfile / ResetBase read the saved copy and reset point.
- Tests that encode it: Tools/offline/autohidemouseover.lua (the cooldowns checks, kept); this matrix.
- Tools/offline/migrate-test.lua strips every done-flag and reruns the updates: on settings saved after v2.1.24 it
  shows this step turning the page on in a blank Auto-Hide UI copy. A tool artifact (the flag is never lost in
  play: Reset Settings keeps the ...V1 marks), not a player state.

## States (the matrix)
profile (Auto-Hide UI, Blank Slate, Subtle, Balanced, one of your own) x where the settings come from (v2.1.23,
the update not run yet / saved after it) x the saved copy (none, nothing for it, on, off) x its reset point (none,
nothing for it, off) x on that profile at login or another. Outcome: the switch now, after switching to the
profile, after Reset profile. Pins: worked out from v2.1.23's bases (read from v2.1.23's code, both clients).
240 cells per client.
Test: Tools/offline/profilekeepmatrix.lua forever cooldowns
Test: Tools/offline/profilekeepmatrix.lua retail cooldowns

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| profilekeep-cooldowns | profile=AutoHideUI from=v2.1.23 saved=blank | * | * |
| profilekeep-cooldowns | profile=AutoHideUI from=v2.1.23 point=blank | * | * |

(10 cells per client: a blank saved copy now loads on; a blank reset point now resets to on.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (autohidemouseover.lua's cooldowns checks were added with the fix) | | | | |

## Open (user's call)
- Reset with no reset point on a profile you'd used on v2.1.23 gives today's base (off), pinned so: Reset means
  "the built-in's values as they are now". If Reset should keep v2.1.23's on, the step would also need to write a
  reset point, which nothing does today.
- A copy saved on v2.1.23 with nothing for the page but a point with nothing either: both on now (pinned).

## Risk
low: one once-only step on two stores of one profile. Not proven offline: the real logout save (SaveProfile at
PLAYER_LOGOUT), stubbed by switching profiles.
