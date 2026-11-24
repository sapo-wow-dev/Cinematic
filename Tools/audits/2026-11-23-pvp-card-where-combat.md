# Card Vision: the PvP fight card plays only where Entering combat's would (fix card)
Fix: with Entering combat's Show in row limited (dungeons only, say), a fight against players elsewhere still played the Entering a PvP fight card
Found by: release review 2026-11-23 (7b0d220 / e902b95)
Code: Visions/CombatVision.lua: FightCard
Clients: both
Base: 4d01a3a

## Before / after
- Before: Entering combat ticked but its Show in row saying not here (out in the world, with it set to dungeons only): no card in a fight against mobs, but the Rival card and its sound in a fight against players, where no fight card played before the PvP card came.
- After: the PvP card swaps in only where Entering combat's own Show in row says yes too (e902b95: "in place of Entering combat's"). Where it says no, no fight card at all, against players too.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FightCard combatPvp cardCombatPvpOn`, read every hit.)
- Players: those with Entering combat limited by its Show in row and the PvP card ticked (off for existing players, pvpCardOffV1; on for new installs, whose Entering combat is off, so no card either way).
- Other features: FightCard only; Cards.Fire still gates the card that's fired by its own row (combatIn's when not swapped, combatPvp's when swapped), so no row is read twice for one card.
- Other addons: none.
- Tests that encode it: Tools/offline/pvpcard.lua (rows not stubbed but "its Show in row says no -> Entering combat": unchanged), pvpcardmatrix.lua (rows as the stand-in's: unchanged), pvpcardupdate.lua, Dev/PvpCardTest.lua.

## States (the matrix)
Entering combat's Show in row here/not, the PvP fight row on/off, its Show in row here/not, the foe a mob or an enemy player; the client. (Card Vision and Entering combat's tick on and off: pvpcardmatrix.lua.)
Test: Tools/offline/pvpcardrowmatrix.lua forever
Test: Tools/offline/pvpcardrowmatrix.lua retail
Test: Tools/offline/pvpcardmatrix.lua forever
Test: Tools/offline/pvpcardmatrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| pvpcard-rows | enterRow=not pvp=on pvpRow=here foe=player | card=combatPvp | card=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with the PvP card ticked and Entering combat's Show in row limited, in a fight against players where that row says no: they now get no card there, as before the PvP card. Pinned: every row/tick/foe cell, both clients. Not proven offline: the real Show in rules (the matrix stubs ns.RowOnNow's answer per row).
