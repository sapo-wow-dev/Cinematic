# Cameras: an NPC's line costs nothing with Chat Cam off (fix card)
Fix: every NPC say, yell or party line started a half-second per-frame bubble scan and wrote Chat Cam's debug log, with Chat Cam off or turned off here
Found by: audit 2026-11-25 (gating, finding D9 in 2026-11-25-gating-findings.md)
Code: Camera/ChatCam.lua: the watcher's OnEvent; Camera/CameraScripts.lua: heardFrame's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: Chat Cam off (its rows off or set to no camera), or Enable Cameras off: each NPC line near
  you still waits for its bubble (a scan of the bubbles every frame for up to half a second), twice
  (Chat Cam's and the camera scripts' listeners), and Chat Cam writes its debug log line.
- After: Chat Cam waits only while it's on here (or a conversation of it is on, or its Test runs), or
  its script scene plays with Ultra immersive's subtitles; the camera scripts' listener only while a
  script plays (its rules hear lines), a chat script conversation is on, or a Chat row is set to a script.
  The Target the speaker key still takes each speaker's name, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs WhenBubble chatCamDebug ChatNow`)
- Players: none (nothing to see came of it). The debug log no longer lists lines heard with Chat Cam off.
- Other features: CameraScripts.lua's heard (a running script's "someone talks" rule, its look at the
  speaker): kept while a script runs. ChatNow's start for a Chat row set to a script: kept (ScriptRow).
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
Chat Cam's rows set to it (on) or no camera (off), Enable Cameras on or off, its script scene playing
with subtitles or not.
Test: Tools/offline/chatcamoffmatrix.lua forever
Test: Tools/offline/chatcamoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chat-cam-off | script=no row=none | waits | no wait |
| chat-cam-off | script=no row=chat cameras=off | waits | no wait |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Chat Cam on here goes the same way. Not proven offline: a script with a "someone talks" stop rule
in game (kept by the run check), the real bubbles.
