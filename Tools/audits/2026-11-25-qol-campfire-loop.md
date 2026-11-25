# Campfire: its watch runs only while the sit button, a listener or the Campfire scene wants it (fix card)
Fix: the campfire watch ran every frame for everyone, always (its gate read sceneOffCampfire, nil by default), with Cameras left out or Enable Cameras off too, and read every world tooltip
Found by: audit 2026-11-25 (gating, finding D1 in 2026-11-25-gating-findings.md)
Code: QoL/Campfire.lua: Wanted (new), the driver's FeatureLoop wanted(), the GameTooltip OnShow hook
Clients: both
Base: baabf86

## Before / after
- Before: every player: the campfire watch's loop every frame (its checks ten times a second) and each
  world tooltip read for a campfire or tent name, whatever was on.
- After: only while the campfire card's Fire button is on, something listens for the cursor resting on
  a fire (Emote Vision's campfire card, a trigger of yours), or the Campfire scene can play (Cameras
  loaded, the Scenes page on with Enable Cameras above it, its row giving it a camera here) or a cozy
  camera is on (it looks for your tent). The tooltip hook returns at once otherwise.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CAMPFIRE_REST sceneOffCampfire CampfireButtonOn WatchCozy`)
- Players: none see a difference: with none of those on, nothing used what it found.
- Other features: Emote Vision's campfire card and the Sleeping Bag (CAMPFIRE_REST listeners, their own
  wanted): kept by ns.SignalWanted. Your triggers' "campfire" moment (CustomTriggers.lua): its
  listener's wanted. The cozy camera's tent (WatchCozy): kept while the Campfire scene can play, or a
  cozy camera is on (seen at the next 1 s loop sync).
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
Enable Cameras on or off, the Campfire scene's row on or off, the Fire button on or off, a CAMPFIRE_REST
listener wanting it or not.
Test: Tools/offline/campfireloopmatrix.lua forever
Test: Tools/offline/campfireloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| campfire-loop | scene=off button=off listen=no | loop off, tooltip read | loop off, tooltip skipped |
| campfire-loop | cameras=off scene=on button=off listen=no | loop on, tooltip read | loop off, tooltip skipped |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: on whenever one of its users can use it. With the Campfire scene on (its default) and Enable
Cameras on, it still runs as before. Not proven offline: a cozy camera from another scene (Stand
still set to cozy) seeing a tent within the first second.
