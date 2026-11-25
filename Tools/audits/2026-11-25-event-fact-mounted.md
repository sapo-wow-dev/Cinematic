# Rules: mounted asked when you mount or dismount, not every working out (fix card)
Fix: the rule facts asked IsMounted on every full working out (every 0.1 s, 0.5 s idle) for every player (mounted is always worked out: Shoulder Cam reads it), though the game sends PLAYER_MOUNT_DISPLAY_CHANGED for each mount and dismount
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the mounted entry (ns.AddEventFact), ns.RuleFacts (the mounted line)
Clients: both
Base: 5da0c5d

## Before / after
- Before: facts.mounted = IsMounted() each full working out.
- After: asked once, then after PLAYER_MOUNT_DISPLAY_CHANGED or a loading screen (and for 0.5 s after each). Same word. The flight path (taxi) stays read live: ns.OnTaxi is already asked once a frame and shared by the place, the cameras and the cards, so a copy kept by event would save nothing.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsMounted facts.mounted`, read every hit.)
- Players: rules naming mounted; Shoulder Cam's mounted check (ShoulderCam.lua: facts.mounted, with its own PLAYER_MOUNT_DISPLAY_CHANGED watcher).
- Other features: the cameras, the Skyriding camera and the cards read IsMounted themselves: untouched.
- Other addons: none.
- Tests that encode it: factswords, chatbgsettle, idletick, shoulderformread, rangehint, manavision, shoulderghostwolf pass.

## States (the matrix)
The states: mounted or not, nothing new or flipped with PLAYER_MOUNT_DISPLAY_CHANGED. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever mounted
Test: Tools/offline/eventfactsmatrix.lua retail mounted

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-mounted | word=mounted start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-mounted | word=mounted start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-mounted | word=mounted start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-mounted | word=mounted start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: Shoulder Cam reads it. Not proven offline: PLAYER_MOUNT_DISPLAY_CHANGED for every way of mounting on Forever (a mount in a fight's end, a vehicle, a druid's travel or flight form, which IsMounted never counted), and that IsMounted answers within the 0.5 s settle. For the test skill's run: mount and dismount with Shoulder Cam on, and a rule naming mounted.
