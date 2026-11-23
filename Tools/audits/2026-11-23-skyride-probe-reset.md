# Reset: a Skyriding probe's camera setting still comes back (fix card)
Fix: a Reset in the seconds a /cine debug skyride probe ran wiped its note of your field of view or camera follow, so the probe's value stayed for good
Found by: audit 2026-11-23 (the sweep after ca8a9fb)
Code: Profiles/Profiles.lua: ns.ResetAddon (what it keeps)
Clients: retail
Base: 308f038

## Before / after
- Before: the fov and follow probes write cameraFov or cameraSmoothStyle for 4-6 s and note yours in db.skyrideProbeRestore; a /reload mid-probe puts yours back at the next login. A Reset (Settings or Everything) mid-probe wiped the saved settings and reloaded: no note, so the probe's 20-narrower field of view or follow style stayed.
- After: the reset keeps the note (like worldTextLive, both kinds of reset), and the next login puts yours back as after any /reload.

## Who relies on the old behavior
(`python -I Tools/audit.py refs skyrideProbeRestore ResetAddon`, every hit read.)
- Players: a debug command on retail only (SkyrideCam.lua returns on other clients); nothing relies on it being wiped.
- Other features: the note is read only by SkyrideCam.lua's Hold, Restore and its login put-back, which clears it once done. Kept on a Reset Everything too: it's a game setting of yours, not something of Cinematic's.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
The probe's setting (cameraFov or cameraSmoothStyle); no reset, Reset Settings or Reset Everything mid-probe; then the reload (logout, the saved settings loaded, login).
Test: Tools/offline/skyrideproberesetmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| skyride-probe-reset | probe=cameraFov reset=settings | 70 (the probe's) | yours |
| skyride-probe-reset | probe=cameraFov reset=everything | 70 (the probe's) | yours |
| skyride-probe-reset | probe=cameraSmoothStyle reset=settings | 0 (the probe's) | yours |
| skyride-probe-reset | probe=cameraSmoothStyle reset=everything | 0 (the probe's) | yours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a retail debug probe only, and one more key a reset keeps. Not proven offline: a camera script holding cameraSmoothStyle at the same moment (the follow sets share savedCVars, the probe writes it itself, as before).
