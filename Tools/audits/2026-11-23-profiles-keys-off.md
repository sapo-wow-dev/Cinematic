# Profiles: saved Auto-Hide UI and Blank Slate keep their wheels and the Keyboard Map (fix card, retroactive)
Fix: v2.1.24 turned the wheels' and the Keyboard Map's switches off in Auto-Hide UI's and Blank Slate's bases
(09daeb7). A copy of either saved on v2.1.23 held nothing for them (on in the base then), so switching back to it,
or its Reset, turned every wheel key and the Keyboard Map key off.
Found by: release review 2026-11-22; fixed in ae2cda8 (card written after, 2026-11-23)
Code: Migrations.lua: the profileKeysOffV1 step; Profiles/ProfileModules.lua: ns.PROFILE_KEYS_OFF
Clients: both
Base: ae2cda8^

## Before / after
- Before: you'd used Auto-Hide UI or Blank Slate on v2.1.23. After the update, switching back to it, or Reset with
  a reset point from v2.1.23, left your wheel keys and the Keyboard Map's key doing nothing.
- After: the saved copy and the reset point keep each of them as you had it, once. A first pick, or a Reset with
  no reset point, gets them off (the built-in as it is now). Turned off yourself: stays off.
- Never affected: being on the profile at the update (the live switches are yours).

## Who relies on the old behavior
(`python -I Tools/audit.py refs profileKeysOffV1 PROFILE_KEYS_OFF`)
- Players: v2.1.23 Auto-Hide UI / Blank Slate users with a saved copy or reset point.
- Other features: Profiles.lua Load / ResetProfile; the welcome window's Also in Cinematic row turns them on by hand.
- Tests that encode it: Tools/offline/autohidemouseover.lua (the wheels checks, added with the fix); this matrix.
- As for the Cooldown Manager card: Tools/offline/migrate-test.lua reruns the step with every flag stripped, so on
  settings saved after v2.1.24 it shows the keys turned on in blank copies. A tool artifact, not a player state.

## States (the matrix)
The same matrix as 2026-11-22-profiles-autohide-cooldowns.md, for the Master wheel and the Keyboard Map in each
cell (the step goes over its list key by key; the other six wheels as the Master wheel): profile x v2.1.23 or
saved after x saved copy x reset point x on it at login. 240 cells per client.
Test: Tools/offline/profilekeepmatrix.lua forever keysoff
Test: Tools/offline/profilekeepmatrix.lua retail keysoff

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| profilekeep-keysoff | profile=AutoHideUI from=v2.1.23 saved=blank | * | * |
| profilekeep-keysoff | profile=AutoHideUI from=v2.1.23 point=blank | * | * |
| profilekeep-keysoff | profile=BlankSlate from=v2.1.23 saved=blank | * | * |
| profilekeep-keysoff | profile=BlankSlate from=v2.1.23 point=blank | * | * |

(20 cells per client.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Open (user's call)
- As in the Cooldown Manager card: a Reset with no reset point gives the built-in's off (pinned so).
- The step writes the defaults (on) into the v2.1.23 copies: a later change to a wheel's default won't reach them.

## Risk
low: one once-only step. Not proven offline: the real logout save.
