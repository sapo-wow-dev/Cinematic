# Zone card: the game's zone text hidden again when no card comes (fix card)
Fix: since v2.1.24 (bdb2e1d) the game's own zone, subzone and territory text showed whenever the Zone card row was on but no card came: on every flight (Not on flights, on by default), with the Subzone row off, and within Not again within. Players saw the game's default look in place of their cards.
Found by: player case 2026-11-23 (Forever, v2.1.24: "during flight, into zone, it is set to default"); card audit 2026-11-23, findings 1 and 4; the user's call: "Fix 1 and 4"
Code: Visions/ZoneCard.lua: Card() (flight and gap branches), Decide() (nothing new / Subzone row off)
Clients: both
Base: 2deb1a9

## Before / after
- Before (v2.1.24, v2.1.25): Zone card row on. On a flight path every zone crossed shows the game's own zone text;
  a subzone with the Subzone row off shows the game's subzone name; a place within Not again within, after the
  last card is gone, shows the game's line.
- After (as v2.1.23): with the Zone card row on, the game's lines stay hidden in all three; a card plays where one
  is allowed. The game's lines show only with the Zone card row off, or for a showing no card can take (no name).

## Who relies on the old behavior
- Players: anyone who liked seeing the game's subzone names with the Subzone row off (since v2.1.24, one day).
  With the Zone card row off they still get all the game's text.
- Other features: Flight departure / arrival cards (say where you fly: unchanged); Discovered card (own path,
  unchanged); DaylightUI zone title (Support/DaylightUI.lua: reads its own row, untouched).
- Tests that encode it: zonecardgame.lua checks 2 and 3 (the game's line shows); Dev/ZoneCardTest.lua step 8 part 3
  (card gone within the gap: the game's line shows, proven 2026-11-23); ledger Tools/tests/zone-card-gap.md Q3;
  fix cards 2026-11-23-zone-card-gap.md and -subzone.md (their "shows once it's gone" note).

## States (the matrix)
place (zone / subzone) x the last card (up / gone) x the gap (within / after) x Subzone row x Territory tick x
on a flight with Not on flights (new dimension), per client: 64 cells.
Test: Tools/offline/zonecardmatrix.lua forever
Test: Tools/offline/zonecardmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| zonecard-gameline | card=gone | card=none line=shown terr=shown | card=none line=hidden terr=hidden |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/zonecardgame.lua | 2 (subzone, row off, no card) | the game's subzone line shows | hidden | the user, 2026-11-23: "Yes, change them" |
| Tools/offline/zonecardgame.lua | 3 (within the gap, card gone) | the game's zone + territory lines show | hidden | the user, 2026-11-23: "Yes, change them" |
| Dev/ZoneCardTest.lua | step 8 part 3 (proven) | with no card up the game's line shows | stays hidden; proven mark dropped | the user, 2026-11-23: "Yes, change them" |
| Tools/offline/zonecardmatrix.lua | pins (no new card and none up; card up; subzone row off card up; after the gap) | the game's lines show when no card is up | hidden everywhere, a card after the gap only off a flight (+ flight dimension) | the user, 2026-11-23: "Yes, commit it" |
| Tools/tests/zone-card-gap.md | Q3 (settled YES) | the card gone, within the gap: the game's line shows | stays hidden | the user, 2026-11-23: "Yes, change them" |

## Risk
low: three early returns flip from "show the game's lines" to "keep them hidden", the v2.1.23 behavior players had
for months; 38 of 64 cells unchanged on both clients. Not proven offline: a real flight (OnTaxi stubbed), the
game's frame really staying see-through on Forever while flying (the in-game test's next run).
