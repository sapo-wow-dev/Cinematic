# Zone card: a subzone's game line over a card still up (fix card)
Fix: with the Subzone row off, walking into a subzone while the last Zone card is still on screen showed the game's subzone line ("Goldshire") over our card.
Found by: the audit kit's first matrix (zonecardmatrix), 2026-11-23; the user's call: hide it
Code: Visions/ZoneCard.lua: Uncover() (every "no card this time" path: Subzone row off, the gap, a flight)
Clients: both
Base: e202b4a

## Before / after
- Before: Zone card up for Elwynn Forest, you walk into Goldshire (Subzone row off): the game's "Goldshire" shows
  over or under our card's words.
- After: while the last Zone card is on screen, the game's lines stay hidden whatever the reason no new card comes;
  once it's gone they show (bdb2e1d's rule kept).

## Who relies on the old behavior
- Players: Subzone row off (not the default: storyZoneSubzones = true). Those who turned it off to see the game's
  own subzone line still see it, just not while a Zone card is up (seconds after entering a zone).
- Other features: Discovered card (unchanged: its own path), DaylightUI zone title wait (Support/DaylightUI.lua,
  untouched), the flight path skip (a card still up while flying now covers the lines too; cards don't start on a
  flight).
- Tests that encode it: zonecardgame.lua check 2 (subzone, row off, the card gone: line shows) kept, check 3 kept,
  3b now also by this path; ledger Tools/tests/zone-card-gap.md.

## States (the matrix)
As the gap card: place x the last card x the gap x Subzone row x Territory tick, per client.
Test: Tools/offline/zonecardmatrix.lua forever
Test: Tools/offline/zonecardmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| zonecard-gameline | place=subzone card=up subzoneRow=off | card=none line=shown terr=shown | card=none line=hidden terr=hidden |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (zonecardmatrix's pins already said hidden: the user, 2026-11-23, "Yes, hide it") | | | | |

## Risk
low: one early return in Uncover(); 28 of 32 cells unchanged on both clients. Not proven offline: the card's real
on-screen time in game (the matrix stubs "card up"); a flight starting while a card is still up keeps the lines
hidden till it fades.
