# Profiles: Auto-Hide UI and Blank Slate's Reset keeps the keys you have on (fix card)
Fix: since v2.1.24 a Reset on Auto-Hide UI with no reset point (most players never save one) turned the Cooldown Manager page, every wheel key and the Keyboard Map off; on Blank Slate the wheels and the Keyboard Map. v2.1.23 kept them on (the bases had them on then).
Found by: card audit of the v2.1.24 audit fixes, 2026-11-23 (finding 3, verified by running); the user: "Fix 1, 2, 3"
Code: Migrations.lua: the profileResetKeepV1 step (new, after profileKeysOffV1)
Clients: both
Base: b22b6ce

## Before / after
- Before: on Auto-Hide UI (or Blank Slate) since v2.1.23, no reset point: Reset profile turned those keys off.
- After: once, the update writes each of the two profiles a reset point (only where it has none) holding each of
  those keys you have on: your live switches if you're on the profile, else its saved copy. Reset keeps them on.
  A fresh pick has them off, so nothing's written and Reset gives the built-in as before.

## Who relies on the old behavior
- Players: v2.1.23 Auto-Hide UI / Blank Slate users (live or with a saved copy) and no reset point: Reset keeps
  their keys on again. Also (the price of no saved version to tell them apart): a player who picked either profile
  on v2.1.24 or later and turned one of those keys on themselves: Reset now keeps that key on, where it went off.
- Other features: Profiles.lua ns.ResetBase / ns.ResetProfile (a point on top of the base: unchanged); the
  Profiles page shows the profile as having a reset point; profileKeysOffV1 and autoHideCooldownsV1 (run first).
- Tests that encode it: profilekeepmatrix (cooldowns and keysoff), its point=none pins; autohidemouseover,
  auditsettings (old versions hold).

## States (the matrix)
profilekeepmatrix as before (profile x v2.1.23 or saved after x saved copy x reset point x on it at login), for
handleCooldowns and for the Master wheel and Keyboard Map; the new step's flag cleared in each cell (it runs for
everyone, players already on v2.1.24+ too).
Test: Tools/offline/profilekeepmatrix.lua forever cooldowns
Test: Tools/offline/profilekeepmatrix.lua retail cooldowns
Test: Tools/offline/profilekeepmatrix.lua forever keysoff
Test: Tools/offline/profilekeepmatrix.lua retail keysoff

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| profilekeep-cooldowns | profile=AutoHideUI point=none | * | * |
| profilekeep-keysoff | profile=AutoHideUI point=none | * | * |
| profilekeep-keysoff | profile=BlankSlate point=none | * | * |

(7 cells per client for the Cooldown Manager, 14 for the wheels and Keyboard Map: those whose key loads on.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/profilekeepmatrix.lua | pins, point=none on Auto-Hide UI / Blank Slate with the key on | Reset: today's base (off) | Reset: kept on | the user, 2026-11-23: "Yes, commit it" |
| Tools/audits/2026-11-22-profiles-autohide-cooldowns.md, 2026-11-23-profiles-keys-off.md | Open: "a Reset with no reset point gives the built-in's off (pinned so)" | off | kept on when you have it on | the user, 2026-11-23: "Yes, commit it" |

## Risk
low: one once-only step writing small reset points for two profiles. Not proven offline: the real logout save, the
Profiles page's look with the new point.
