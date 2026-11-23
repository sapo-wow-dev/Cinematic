# Zone card: the game's line under a card still up (fix card)
Fix: within "Not again within" no new card plays; bdb2e1d then showed the game's zone line even while the last card was still on screen, so the place name showed twice.
Found by: player case 2026-11-23 (Forever, v2.1.24, Darrowmere Lake); fixed in e202b4a
Code: Visions/ZoneCard.lua: Card() (the gap branch), Decide(), Uncover()
Clients: both
Base: e202b4a^

## Before / after
- Before (v2.1.24): crossing back over a zone border within the gap, the game's big zone name showed over our card.
- After: while the last Zone card is up, the game's zone and territory lines stay hidden; once it's gone (still
  within the gap) they show, as bdb2e1d meant.

## Who relies on the old behavior
- Players: anyone with the Zone card on (default on) who crosses borders; storyZoneGap default 10 s.
- Other features: Discovered card (ns.DiscoverHasIt), DaylightUI's zone title wait (Support/DaylightUI.lua).
- Tests that encode it: zonecardgame.lua check 3 (card gone: line shows, kept) and 3b (new); ledger
  Tools/tests/zone-card-gap.md; Dev/ZoneCardTest.lua step 8.

## States (the matrix)
place (zone / subzone) x the last card (up / gone) x the gap (within / after) x Subzone row x Territory tick, per client.
Test: Tools/offline/zonecardmatrix.lua forever
Test: Tools/offline/zonecardmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| zonecard-gameline | card=up gap=within | card=none line=shown terr=shown | card=none line=hidden terr=hidden |

## Found next to it
4 cells weren't covered by this fix: a **subzone** with the **Subzone row off** while the last Zone card is up:
the game's subzone line showed over our card. The user, 2026-11-23: "Yes, hide it". Fixed in its own card,
`2026-11-23-zone-card-subzone.md` (Uncover keeps the lines hidden under a card still up).

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (3b added, 3 kept) | | | | |

## Risk
low: one branch of Card(); every other cell of the matrix unchanged on both clients (audit.py card). Not proven
offline: the card's real fade-out timing (the matrix stubs "card up"), ledger Q2/Q3 in game.
