# Cameras: a camera script played over another ends the first (fix card)
Fix: Play on a script's page (or /cine script play) while another script played only stopped the first one's moves (Start's StopAll): its Finish never ran, so its raised max zoom stayed up for the session and its End music never ended.
Found by: audit 2026-11-22 (retroactive card 2026-11-23)
Code: Camera/CameraScripts.lua: ns.PlayCameraScript() (Finish("replaced") first); Finish(), Start(), the update loop's maxHeldTo
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: script A zooms out past your max, you play B over it: the max stayed 2.6 after both were over (until a
  reload); A's When it ends End music never ended the music. B's own Past max worked.
- After: A finishes as a stopped script does: its music ends, its raised max goes back (or stays up while the camera
  is still out past where A started, then goes back once it's in), and B plays.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlayCameraScript`)
- Players: Cinematic's script page Play button and /cine script play, only while one is already playing.
- Other features: Finish("replaced") also clears A's stoppedFor (PlayCameraScript sets it nil after) and calls
  EndCustomKeyScene for a key-started A: not in the matrix (A here is played, not triggered).
- Tests that encode it: Tools/offline/scriptreplace.lua (the fix's own).

## States (the matrix)
A's zoom past max (yes / no) x A's When it ends has End music (yes / no) x the camera when B plays (back where A
started / still out past it) x B's zoom past max (yes / no), per client. Then B stopped and the camera back in.
Test: Tools/offline/scriptreplacematrix.lua forever
Test: Tools/offline/scriptreplacematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| script-replace | aPast=no aMusic=yes bPast=no | playing=B mid=yours music=none after=yours | playing=B mid=yours music=ended after=yours |
| script-replace | aMusic=yes bPast=yes | * | playing=B mid=raised music=ended after=yours |
| script-replace | aPast=yes aMusic=no camera=back bPast=no | playing=B mid=raised music=none after=raised | playing=B mid=yours music=none after=yours |
| script-replace | aPast=yes aMusic=no camera=out bPast=no | playing=B mid=raised music=none after=raised | playing=B mid=raised music=none after=yours |
| script-replace | aPast=yes aMusic=yes camera=back bPast=no | playing=B mid=raised music=none after=raised | playing=B mid=yours music=ended after=yours |
| script-replace | aPast=yes aMusic=yes camera=out bPast=no | playing=B mid=raised music=none after=raised | playing=B mid=raised music=ended after=yours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: 10 of 16 cells per client changed, all A's music or A's raised max; B plays in every cell before and after. Not
proven offline: a key-started (trigger) A replaced from the page (stoppedFor, EndCustomKeyScene), the camera's real
zoom (GetCameraZoom is a stand-in), a fight (Play is refused there).

## Open
- aMusic=yes: pinned "A's End music ends the music as B starts" (as Stop does). If B is meant to keep A's music
  playing, these 8 cells are the user's call.
