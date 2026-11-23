# Cameras: Shoulder Cam off in a fight gives the soft target back (fix card)
Fix: turning the Shoulder Cam off (or logging out) in a fight mid-glide wrote the soft target and Outline Mode back there, which the game refuses (ADDON_ACTION_BLOCKED), then forgot yours: the held 3/2/45 soft target and Outline 0 stayed for good.
Found by: audit 2026-11-22 (retroactive card 2026-11-23)
Code: Camera/ShoulderCam.lua: ns.ApplyShoulderCam() (the off branch), GiveBackForLogout()
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: Shoulder Cam turned off by its key or Enable Cameras in a fight, right as it glided back to a target (soft
  target raised, outlines off), or a logout/reload in a fight then: 4 blocked-action lines, and your soft target
  stayed at 3/2/45 and Outline Mode at 0 after the fight, also after a relog, with or without the cam on again.
- After: nothing protected is written in the fight; centering comes back at once; the soft target and outlines come
  back as the fight ends (or at the next login after a logout in a fight).

## Who relies on the old behavior
(`python -I Tools/audit.py refs ApplyShoulderCam shoulderCamYours GiveBackForLogout offWaiter`)
- Players: anyone with the Shoulder Cam and its Turn to target (glide) on who fights; db.shoulderCamYours now
  can stay saved with only the soft/outline values in it until the fight ends.
- Other features: ShoulderCalibrate.lua, Support/DynamicCam.lua (yield: ShoulderOn() false, same off branch, not
  in the matrix), the /cine debug "applied" line (shoulderCamYours ~= nil reads true while the soft ones wait).
- Tests that encode it: Tools/offline/shoulderfightoff.lua (the fix's own), Dev/ShoulderCamTest.lua.

## States (the matrix)
how it goes off (its key / Enable Cameras / a logout) x fight (out / in) x what it held (glide: soft target,
outlines and centering / plain: centering only) x next (stays off: fight ends or next login with it off / on again
in the fight or at the next login), per client. Stand-in CVar store refuses the soft and outline CVars in fights.
Test: Tools/offline/shoulderoffmatrix.lua forever
Test: Tools/offline/shoulderoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| shoulder-off | fight=in held=glide next=staysoff | blocked=4 soft=held outline=held centered=yours kept=no | blocked=0 soft=yours outline=yours centered=yours kept=no |
| shoulder-off | fight=in held=glide next=onagain | blocked=4 soft=held outline=held centered=held kept=no | blocked=0 soft=yours outline=yours centered=held kept=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: only the in-fight glide cells changed (6 per client), the 18 others the same (audit.py card). Not proven
offline: the real poller giving the soft target back after "on again" (the matrix calls ApplyShoulderCam once out
of the fight, as the poller would), the game really refusing in fights (stand-in), a DynamicCam yield in a fight.

## Open
- next=onagain: pinned "soft target and outlines yours once out of the fight, no glide going" (Turn to target off in
  the matrix). With the glide on again the Shoulder Cam raises them again on its own: not a cell here.
