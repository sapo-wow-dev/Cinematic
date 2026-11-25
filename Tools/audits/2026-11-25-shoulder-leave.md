# Cameras: Shoulder Cam gives everything back as Cameras is left out (fix card)
Fix: unticking Load Cameras with Shoulder Cam on left its offset and focus settings for the game to keep, with no Cameras code after the reload to give them back
Found by: audit 2026-11-25 (gating, finding B2 in 2026-11-25-gating-findings.md)
Code: Camera/ShoulderCam.lua: GiveBackForLogout
Clients: both
Base: badf2f0

## Before / after
- Before: at every logout or reload Shoulder Cam gives back Keep Character Centered, the motion sickness
  option and the soft target, and leaves the offset and the talk/enemy focus for the next session (the
  game clears the offset each session on Forever, tested; retail untested). With Load Cameras unticked,
  no next session's Shoulder Cam comes: whatever the game kept of the focus (and on retail, maybe the
  offset) stays.
- After: with Load Cameras unticked, the logout gives back every Shoulder Cam setting (the soft target
  and outlines as before: refused in a fight, kept for when Cameras loads again). Kept, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs GiveBackForLogout shoulderCamYours`)
- Players: none with Load Cameras ticked (the branch only runs unticked).
- Other features: ApplyShoulderCam reads shoulderCamYours at the next login with Cameras loaded: emptied
  only when unticked, so nothing to read then.
- Other addons: DynamicCam / DialogueUI write the same offset: given back to the value Shoulder Cam found.
- Tests that encode it: engine rule forever.overshoulder.cleared-each-session (unchanged: the kept case
  still relies on it); Tools/offline/modules.lua (cameras left out: no Shoulder Cam code at all).

## States (the matrix)
Load Cameras kept or unticked, in a fight at the logout or not; the client.
Test: Tools/offline/shoulderleavematrix.lua forever
Test: Tools/offline/shoulderleavematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| shoulder-leave | load=unticked | ours: offset,focus | game |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: runs only at a logout with Load Cameras unticked. The offset's write at logout brings no warning (the
game's experimental warning comes on turning it on, not to 0). Not proven in game: whether retail keeps
test_ settings across sessions; the other next-login recoveries in Cameras (a calibration cut off by the
reload, the fishing volume mid-cast, Skyriding's probe, a scene's zoom) still wait for Cameras to load
again: rare, noted in the findings.
