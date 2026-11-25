# Places: where you are asked when the game says it changed, not every frame (fix card)
Fix: ns.GetPlaceType asked the game where you are (the zone's name against the capitals, IsInInstance, IsResting) on every frame something asked (~21 callers: the rules, per-place options, Heal Vision, cameras, cards), though the game announces every change
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Core.lua: ns.GetPlaceType, ns.placeWatch (new)
Clients: both
Base: 096cbe9

## Before / after
- Before: each frame, the first caller of ns.GetPlaceType asked GetRealZoneText, IsInInstance and IsResting (once a frame, OncePerFrame).
- After: asked once, then again only after ZONE_CHANGED, ZONE_CHANGED_NEW_AREA, ZONE_CHANGED_INDOORS, PLAYER_ENTERING_WORLD or PLAYER_UPDATE_RESTING, and on each ask for 0.5 s after (an answer the game sets a moment after its event). The flight path is still read live: a capital or an inn counts as none on one, as before. Same places.

## Who relies on the old behavior
(`python -I Tools/audit.py refs GetPlaceType`, read every hit.)
- Players: every per-place setting (Show in places, Turn off in, Heal Vision places, cards, camera Off in): same places, read from the cache.
- Other features: ns.GetOptionPlace, ns.RuleFacts' place words, Camera.lua and Core.lua debug lines: same answers. /cine debug commands that print the place: the cached one (it's the game's after its last event).
- Other addons: none.
- Tests that encode it: the offline tests that stub the zone, instance or resting (discover*, farnames*, pvpcard*, calmplatesmatrix, newzonedefault, rulewords, statewords, unitwords, valuewords): every matrix 0 cells changed against 096cbe9, the others pass as before (rulewords' autorun check already failed on 096cbe9).

## States (the matrix)
The states: where you start (open world, a capital, an inn, a dungeon, a raid, a battleground), on a flight path or not, nothing new or a move (to the open world; from it into a capital) with the game's events for it. Client fixed per run.
Test: Tools/offline/eventplacematrix.lua forever
Test: Tools/offline/eventplacematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-place | start=world change=none | * | * |
| event-place | start=world change=move | * | * |
| event-place | start=city | * | * |
| event-place | start=inn | * | * |
| event-place | start=dungeon | * | * |
| event-place | start=raid | * | * |
| event-place | start=pvp | * | * |

(Every cell: polled=yes -> polled=no, its place the same; the pins hold every place.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: every per-place setting reads it. Pinned: every place, on a flight or not, moves with their events, both clients; every place-stubbing offline test unchanged. Not proven offline: that the game sends one of the five events for every place change on both clients (a capital's edge without a zone change, a phased area, a portal inside an instance), and that IsInInstance answers by the end of the 0.5 s settle. For the test skill's run: walk into and out of a capital and an inn, zone into a dungeon, take a flight from a city.
