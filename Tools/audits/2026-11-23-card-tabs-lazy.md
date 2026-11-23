# Card Vision: an Events tab switched off holds from login (fix card)
Fix: Card Vision's Events tabs (new in 6f79106) weren't in LazyPageDefaults.lua: until the page was opened, a tab switched off didn't stop its cards (after a login or /reload), and Reset and profile strings didn't carry the tabs' switches
Found by: release review 2026-11-23 (prerelease: "settings pages made on first open", both clients)
Code: LazyPageDefaults.lua (made by Tools/offline/lazyaudit.lua --write): the six tabOn:Card Vision/events:N defaults and their cards' links
Clients: both
Base: HEAD

## Before / after
- Before: Bosses and rares switched off (say), /reload: a rare's card still played until Card Vision's settings page was opened once.
- After: a tab off stops every card on it from login, as the switch tree says (page off = every setting on it off). Opened or not, the same.

## Who relies on the old behavior
- Players: only those who switched an Events tab off; their cards on it stop at login now (what the tab said).
- Other features: ns.Setting walks LAZY_PAGE_SWITCHES' links (combatOnEnter, chatAttackAlert... under tab 1, the page builds the same links when made); profiles and sharing carry the six tab switches (defaults true).
- Other addons: none.
- Tests that encode it: lazyaudit.lua (now 0 problems), lazytabsmatrix.lua (other pages, unchanged), check.lua's profile snapshots (0 problems).

## States (the matrix)
The page not opened since login (the page made is the page's own code, as before): each of the six Events tabs, Card Vision on or off, the tab's switch as saved on or off, a card on it ticked; the client.
Test: Tools/offline/cardtabsmatrix.lua forever
Test: Tools/offline/cardtabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cardtabs-unopened | cards=on tabSwitch=off | on | off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: players with an Events tab switched off see its cards stop at login, as it said. Not proven offline: in game before the page is opened (the stand-in's page build is the game's).
