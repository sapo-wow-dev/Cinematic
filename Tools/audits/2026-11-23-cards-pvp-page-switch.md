# Card Vision: the PvP fight row listed under the page switch (fix card)
Fix: Core.lua's PAGE_SWITCH cards list lacked cardCombatPvpOn, the only card event switch missing from it
Found by: release review 2026-11-23
Code: Core.lua: PAGE_SWITCH (the cards list), read by ns.Setting / ns.PageSetting / ns.PageSwitchOf
Clients: both
Base: HEAD

## Before / after
- Before: no change a player could see: LazyPageDefaults.lua (the switch tree read at login) already puts cardCombatPvpOn under the Events tab (tabOn:Card Vision/events:1), which is under cards, on both clients; and ns.CardOn asks ns.Setting("cards") itself. The static list was only out of step with the rule.
- After: the same, with the static list complete (a regenerated tree that dropped the row would still leave it under Card Vision's switch).

## Who relies on the old behavior
- Players: none (same reads).
- Other features: ns.Setting/ns.PageSetting chains; ns.MapTabContainers and LazyPageDefaults.lua override the entry with the tab key (as for every other card row).
- Other addons: none.
- Tests that encode it: Tools/offline/sweep.lua (0 new FAIL, 0 gone, both clients), lazytabs.lua, pvpcard.lua, pvpcardupdate.lua (all PASS).

## States (the matrix)
The row (cardCombatPvpOn, neighbor cardDuelOn), Card Vision on/off, the row's tick on/off, CineMode on/off, Allow outside CineMode on/off; the client.
Test: Tools/offline/cardspageswitchmatrix.lua forever
Test: Tools/offline/cardspageswitchmatrix.lua retail

## Meant to change
Nothing (0 changed cells on both clients: the tree already gated it).
| Matrix | Cell | Before | After |
|--------|------|--------|-------|

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a list entry the login tree already overrides; no cell changes. Not proven offline: nothing in game differs.
