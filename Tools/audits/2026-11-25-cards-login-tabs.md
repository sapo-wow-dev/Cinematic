# Cards: Last time and the time of day at login go by their events' tabs (fix card)
Fix: with Last time's Settings tab off its line still showed at login, with its Sounds tab off the page turned
aloud, and with the Zone event's Settings tab off "Time of day at login" still showed
Found by: audit 2026-11-25 (gating, finding C20 in 2026-11-25-gating-findings.md)
Code: Core.lua: the PLAYER_ENTERING_WORLD login lines; Visions/Recap.lua: ns.RecapCard, ns.RecapDemo
Clients: both
Base: baabf86

## Before / after
- Before: Cards page, Last time event, Settings tab switched off: at login "Last time: Darkshore · 3 quests"
  still showed under the zone name (as a line; as a card, Cards.lua already held it). Its Sounds tab off: the
  line still played the page-turn sound. The Zone event's Settings tab off (where Time of day at login is
  ticked): "Dusk" still showed under the zone name.
- After: each tab off is a container: no Last time line (or card) with its Settings tab off, no page-turn
  sound with its Sounds tab off, no time of day with the Zone event's Settings tab off. The page's Test
  (ns.RecapDemo) goes by the same.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RecapCard ShowTimeOfDayTitle timeOfDayMessage storyRecap`)
- Players: those who switched one of these tabs off wanted it gone; with the tabs on (the default) nothing
  changes. "Time of day at login" sits in the Zone event's Settings (CardsPage.lua parts.Part("zone")), so
  that tab is its container, not the Time of day event's.
- Other features: the zone card's own time line (ns.ZoneCardTime) unchanged; the card path's sound is
  Cards.lua's Show, already asking the Sounds tab.
- Other addons: a card yielded to another addon (ns.FeatureYieldedTo "card:login") now also drops the line,
  as ns.CardOn asks it.
- Tests that encode it: timetitlematrix.lua (tinttest/timetest with Visions in or out), unchanged.

## States (the matrix)
Last time as a card or a line; its Settings and Sounds tabs; the Zone event's Settings tab; a real login.
Test: Tools/offline/loginlinesmatrix.lua forever
Test: Tools/offline/loginlinesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| login-lines | under=card loginSettings=on zoneSettings=off | time=yes recap=card sound=no | time=no recap=card sound=no |
| login-lines | under=card loginSettings=off zoneSettings=off | time=yes recap=none sound=no | time=no recap=none sound=no |
| login-lines | under=line loginSettings=on loginSounds=on zoneSettings=off | time=yes recap=line sound=yes | time=no recap=line sound=yes |
| login-lines | under=line loginSettings=on loginSounds=off zoneSettings=on | time=yes recap=line sound=yes | time=yes recap=line sound=no |
| login-lines | under=line loginSettings=on loginSounds=off zoneSettings=off | time=yes recap=line sound=yes | time=no recap=line sound=no |
| login-lines | under=line loginSettings=off zoneSettings=on | time=yes recap=line sound=yes | time=yes recap=none sound=no |
| login-lines | under=line loginSettings=off zoneSettings=off | time=yes recap=line sound=yes | time=no recap=none sound=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only with one of those tabs switched off. Your call: the time of day goes by the Zone event's Settings
tab (where its tick is), not the Time of day event's. Not proven in game: the real zone text at login (the
matrix stubs ns.ShowTimeOfDayTitle and the sound).
