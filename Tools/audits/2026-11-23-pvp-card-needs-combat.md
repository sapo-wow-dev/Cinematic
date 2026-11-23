# Card Vision: the PvP fight card needs Entering combat (fix card)
Fix: with Entering combat unticked, a fight against players still played the Entering a PvP fight card (new installs: every battleground fight)
Found by: release review 2026-11-23
Code: Visions/Cards.lua: EVENTS combatPvp (needs = "combatIn"), read by ns.CardOn / ns.CardAllowed
Clients: both
Base: HEAD

## Before / after
- Before: Entering combat unticked (a new install starts so), Entering a PvP fight ticked: no card in a fight against mobs, but the Rival card and its sound in every fight against players.
- After: the PvP card plays only in place of Entering combat's: Entering combat unticked, no fight card at all. Its row greys under Entering combat on the Events tab (CardsPage's needs).

## Who relies on the old behavior
- Players: new installs have Entering combat off and the PvP card on, so they saw PvP cards only; existing players have the PvP card off (pvpCardOffV1).
- Other features: CombatVision.lua FightCard asks ns.CardOn("combatPvp") then ns.CardAllowed; the Why window's "is unticked" line now names Entering combat.
- Other addons: none.
- Tests that encode it: Tools/offline/pvpcard.lua (sets combatOnEnter on: unchanged, ALL PASS), pvpcardupdate.lua (ALL PASS), Dev/PvpCardTest.lua (turns combatOnEnter on itself).

## States (the matrix)
Card Vision on/off, Entering combat on/off, PvP fight row on/off, the foe a mob or an enemy player; the client.
Test: Tools/offline/pvpcardmatrix.lua forever
Test: Tools/offline/pvpcardmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| pvpcard-fight | cards=on enter=off pvp=on foe=player | card=combatPvp | card=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with Entering combat off and the PvP row on (new installs) notice: the PvP card no longer plays alone. Not proven offline: the Events tab greying the row in game.
