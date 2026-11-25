# Cameras: Quest Cam off, quest talks aren't followed and its loop doesn't run (fix card)
Fix: with Quest Cam off (its row no camera, Enable Cameras or the Scenes page off), every quest or gossip window still started following the talk, and Quest Cam's update loop ran through it; the mouse's pass over units was watched every frame for nothing
Found by: audit 2026-11-25 (gating, finding D12 in 2026-11-25-gating-findings.md)
Code: Camera/QuestCam.lua: TalkWanted (new), OnEvent, the pass watcher's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: Quest Cam off. Talking to a quest giver, the talk is followed (cam.since) and Quest Cam's
  loop runs every frame till it's over (its moves and zooms stepping nothing). The mouse on any unit:
  its pass across the screen is watched every frame.
- After: the talk is followed only with the quest camera or its script on here for it (the Quest or
  Quest gossip row has a camera). The pass is watched only for those or Quest talk (Quest Vision),
  whose Opposite clicked reads it (ns.ClickedX). Quest Cam on: the same as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs QuestTalkNow ClickedX QuestCamWindowUp QuestCamClosedAt`)
- Players: none (Quest Cam off did nothing with it).
- Other features: quest camera scripts (CameraScripts.lua TriggerNow's QuestTalkNow, the Its quest
  window closes rule): their row has a camera, so the talk is still followed. Quest talk
  (Visions/QuestTalk.lua) uses only ns.ClickedX (the click watcher, unchanged, and the pass, kept
  while it's on) and ns.QuestCamSide (inert with Quest Cam off). The Director's questtalk and the Why
  window read QuestTalkNow: nil now with no quest camera or script, as nothing plays then.
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
The Quest row set to the quest camera, its script or no camera; Enable Cameras on or off; Quest talk
on or off. (In the dev copy the quest camera plays as its script.)
Test: Tools/offline/questcamoffmatrix.lua forever
Test: Tools/offline/questcamoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| quest-cam-off | row=none talk=off | talk on, loop on, pass on | talk off, loop off, pass off |
| quest-cam-off | row=none talk=on | talk on, loop on, pass on | talk off, loop off, pass on |
| quest-cam-off | cameras=off talk=off | talk on, loop on, pass on | talk off, loop off, pass off |
| quest-cam-off | cameras=off talk=on | talk on, loop on, pass on | talk off, loop off, pass on |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Quest Cam or its script on goes as before. A Quest row whose When doesn't fit as the window opens
(off here) isn't followed for that talk, as it couldn't play. Not proven offline: the player copy's
quest camera (its own code, not as a script), gossip windows.
