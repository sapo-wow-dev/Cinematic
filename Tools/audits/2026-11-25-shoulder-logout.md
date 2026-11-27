# Cameras: Shoulder Cam's logout give-back tries each setting on its own (fix card)
Fix: at a logout or reload, one Shoulder Cam setting the game refused (a Lua error from SetCVar) stopped the give-back, and with Load Cameras unticked one that didn't take was dropped from what's kept anyway
Found by: audit 2026-11-25 (review of 65908f6, the Load Cameras unticked give-back)
Code: Camera/ShoulderCam.lua: GiveBackForLogout
Clients: both
Base: cc7e40d

## Before / after
- Before: GiveBackForLogout called SetCVar bare for Keep Character Centered / the motion sickness option,
  and (Load Cameras unticked) for the offset and the focus. One refused with a Lua error stopped the
  function there: the settings after it were neither given back nor cleared from shoulderCamYours, the
  soft target too if it was Keep Character Centered, and a Lua error at the logout. With Load Cameras
  unticked no Cameras code runs the next session to finish it. A write that didn't take (blocked) was
  still cleared from shoulderCamYours, so it was lost for good.
- After: each setting is tried on its own (pcall, as the soft-target loop already did). One that reads
  back as yours is cleared from shoulderCamYours; one refused stays kept for when Cameras loads again
  (ApplyShoulderCam's next login); the others still go back; no Lua error. Nothing changes when the game
  takes every write.

## Who relies on the old behavior
(`python -I Tools/audit.py refs GiveBackForLogout shoulderCamYours`, every hit read.)
- Players: none rely on it: the change is only in the refused cells (the ordinary logout is the same).
- Other features: ApplyShoulderCam (next login, Cameras loaded) reads shoulderCamYours: a refused one
  left in it is given back there, as the soft target already is (2026-11-22 fight-off card).
  The /cine debug "applied" line reads shoulderCamYours ~= nil: true while a refused one waits.
- Other addons: none (DynamicCam / DialogueUI write the same offset: given back to the value Shoulder Cam found, as before).
- Tests that encode it: Tools/offline/shoulderleavematrix.lua, shoulderfightoff.lua, shoulderoffmatrix.lua
  (no refused write in any: unchanged); cards 2026-11-25-shoulder-leave.md, 2026-11-22-cameras-shoulder-fight-off.md;
  engine rule forever.softtarget.cvars-protected-combat (pcall doesn't catch a BLOCKED: the read-back
  check covers that kind, the "blocked" cells).

## States (the matrix)
Load Cameras kept or unticked; in a fight at the logout or not; which setting the game refuses (none, the
offset, Keep Character Centered, the focus, the soft target) and how (a Lua error, or a write that
doesn't take); the client.
Test: Tools/offline/shoulderlogoutmatrix.lua forever
Test: Tools/offline/shoulderlogoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| shoulder-logout | load=kept fight=no refused=centered kind=error | * | ours: offset,centered,focus; kept: offset,centered,focus; error: no |
| shoulder-logout | load=kept fight=yes refused=centered kind=error | * | ours: offset,centered,focus,soft; kept: offset,centered,focus,soft; error: no |
| shoulder-logout | load=unticked fight=no refused=offset | * | ours: offset; kept: offset; error: no |
| shoulder-logout | load=unticked fight=no refused=centered | * | ours: centered; kept: centered; error: no |
| shoulder-logout | load=unticked fight=no refused=focus | * | ours: focus; kept: focus; error: no |
| shoulder-logout | load=unticked fight=yes refused=offset | * | ours: offset,soft; kept: offset,soft; error: no |
| shoulder-logout | load=unticked fight=yes refused=centered | * | ours: centered,soft; kept: centered,soft; error: no |
| shoulder-logout | load=unticked fight=yes refused=focus | * | ours: focus,soft; kept: focus,soft; error: no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only when the game refuses a camera setting at a logout (a reload in a fight; no camera CVar but the
soft target is known protected, Tools/engine/rules). The ordinary logout is unchanged (26 of 40 cells the
same, both clients). Not proven in game: which of test_cameraOverShoulder / the focus / Keep Character Centered the
game refuses in a fight, and whether a refusal there is a Lua error or a BLOCKED (both kinds are in the
matrix).
