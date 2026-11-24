# Atmosphere: the haze update keeps a haze you picked (fix card)
Fix: the once-only haze update (dofScaleV2) set Haze strength to 0 for every player, profile and reset point, even a haze a player had raised (or lowered) themselves
Found by: release review 2026-11-23 (the user: "keep hand-picked haze")
Code: Migrations.lua: ns.HazeToOneStrength, the dofScaleV2 step
Clients: both
Base: HEAD

## Before / after
- Before: updating from v2.1.27, everyone's haze went off (Haze strength 0) and the camera modes' own strengths (dofIdle, dofCozy, dofVista, dofFish, dofFlight, dofWalk, dofRun) were removed, whatever they had set.
- After: a save still at v2.1.27's defaults (Haze strength 100%, the modes' 2.5%, Walk and Run 0) gets the new default, 0 (no haze), as before. A haze you'd picked is kept: Haze strength becomes the strongest haze you saw then (a mode's strength times the old Haze strength; a Haze strength of your own counts for every mode), at most 100%. A haze you'd turned Off stays off. The modes' own keys still go. (The dev copy's dofStrengthV1, never released, had raised the 2.5% to 15%: 15% counts as that default there.)

## Who relies on the old behavior
(`python -I Tools/audit.py refs HazeToOneStrength dofScaleV2 OLD_DOF_MODE_KEYS`, every hit read.)
- Players: v2.1.27 saves (Haze strength 1, modes 0.025 / 0). New code reads only dofScale (Atmosphere/Focus.lua WantedStrength: min(1, dofScale)); the old read min(1, dof<Mode> * dofScale), so the carried value is the old visible alpha of the strongest mode. The haze's texture changed too (a pale mist), so the look isn't identical, only its strength.
- Other features: Options.lua's Haze strength slider (0-100%) and its greying ((dofScale or 0) > 0); CameraScripts.lua's built-in cameras read dofScale. A script of your own's Edge haze is no longer times dofScale: not this fix.
- Other addons: none.
- Tests that encode it: Tools/offline/atmopreview.lua "an old save's haze: 0, the modes' own gone, its switch kept" (input dofScale 2, dofIdle 0.15: a picked 200% scale): its expectation changes (below). Dev/AtmosphereTest.lua checks DEFAULTS.dofScale == 0 only: unchanged. `upgrade-check.py`: the plain, flipped and own players are all at the old defaults (dofScale 1, modes 0.025), so CHANGED dofScale 1 -> 0 stays for them, as meant.

## States (the matrix)
Old Haze strength (none, 100%, 50%, 200%, Off), Standing still's own (none, 2.5%, 15%, 30%, Off), Walk's own (0, 10%), the dev copy's 15% raise run or not; the client.
Test: Tools/offline/hazekeepmatrix.lua forever
Test: Tools/offline/hazekeepmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| haze-keep-picked | walk=0.1 | haze=0 modes=gone switch=true | haze=0.1 modes=gone switch=true |
| haze-keep-picked | idle=0.3 | haze=0 modes=gone switch=true | haze=0.3 modes=gone switch=true |
| haze-keep-picked | idle=0.15 dev=no | haze=0 modes=gone switch=true | haze=0.15 modes=gone switch=true |
| haze-keep-picked | scale=0.5 | haze=0 modes=gone switch=true | haze=0.0125 modes=gone switch=true |
| haze-keep-picked | scale=0.5 walk=0.1 | haze=0 modes=gone switch=true | haze=0.05 modes=gone switch=true |
| haze-keep-picked | scale=0.5 idle=0.15 | haze=0 modes=gone switch=true | haze=0.075 modes=gone switch=true |
| haze-keep-picked | scale=0.5 idle=0.3 | haze=0 modes=gone switch=true | haze=0.15 modes=gone switch=true |
| haze-keep-picked | scale=2 | haze=0 modes=gone switch=true | haze=0.05 modes=gone switch=true |
| haze-keep-picked | scale=2 idle=0.15 | haze=0 modes=gone switch=true | haze=0.3 modes=gone switch=true |
| haze-keep-picked | scale=2 walk=0.1 | haze=0 modes=gone switch=true | haze=0.2 modes=gone switch=true |
| haze-keep-picked | scale=2 idle=0.3 | haze=0 modes=gone switch=true | haze=0.6 modes=gone switch=true |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/atmopreview.lua | an old save's haze: 0, the modes' own gone, its switch kept | an old save (dofScale 2, dofIdle 0.15) set to 0 | a picked 200% kept: 0.3 (0.15 x 2), modes gone, switch kept | NEEDED: not yet (the user's "keep hand-picked haze" covers the intent; the check line itself needs their yes) |

## Risk
low: only players who had changed a haze strength on v2.1.27 notice (they keep a haze instead of none); everyone at the defaults gets 0 as before. Pinned: 100 cells both clients. Not proven offline: the update running in game on a real v2.1.27 save (the stand-in calls ns.HazeToOneStrength directly; the STEP's loop over profiles/reset points is as before), and how the carried strength looks with the new pale mist.
