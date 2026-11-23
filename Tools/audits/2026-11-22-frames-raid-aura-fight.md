# Frames: the raid aura stand-in waits for a fight's end (fix card)
Fix: on WoW Forever the raid frames' Buffs/Debuffs rows switch the game's raidFramesDisplayBuffs/Debuffs (the icons
are out of reach); it switched in a fight too, and each switch has the game rebuild its secure raid frames.
Found by: audit 2026-11-22; fixed in bdb2e1d (retroactive card, 2026-11-23)
Code: Frames.lua: AddAuraStandIns (the set made secure = true), the group watch (PLAYER_REGEN_ENABLED too),
auraStandIns.Apply; Core.lua ns.ApplyCVarSet (secure sets wait out fights)
Clients: forever (retail: no stand-in, the icons fade as parts)
Base: bdb2e1d^

## Before / after
- Before: a raid row fading or coming up mid-fight switched the game's aura setting at once (a raid frame rebuild in
  the fight).
- After: in a fight the setting stays as it was; it's switched as the fight ends, to what the row says then.

## Who relies on the old behavior
(`python -I Tools/audit.py refs auraStandIns raidFramesDisplayBuffs`)
- Players: Forever raiders with the raid Buffs/Debuffs rows faded by a rule (In combat, Show in): the auras now come
  and go only out of a fight. Someone wanting their raid buffs to show the moment a fight starts no longer gets that
  (the fade's own Show in for fights has the auras the way they were before the pull).
- Other features: the Game Settings page (playerWins, heldCVars), ns.Suspend's put-back (RestoreEverything).
- Other addons: none.
- Tests that encode it: Tools/offline/fightsfades.lua check 3 (kept).

## States (the matrix)
the row (faded / shown) x in a group (yes / no) x the change seen in a fight (yes / no) x the setting already ours
(held / free), per client. 16 cells per client (retail: no stand-in).
Test: Tools/offline/raidaurasmatrix.lua forever
Test: Tools/offline/raidaurasmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| raid-aura-standin | fight=yes start=held | during=1 after=1 | during=0 after=1 |
| raid-aura-standin | fight=yes start=free row=faded group=yes | during=0 after=0 | during=1 after=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: Forever, raid frames only. Not proven offline: the stand-in's SetAlpha hook (the stand-in's stub method can't
carry it: the change goes in as a group change, the same Apply), and whether the game's rebuild in a fight was ever
blocked or only slow.

## Open
- user's call: auras faded off for a fight's start stay off for the whole fight when the row says show in it
  (fight=yes start=held: during=0). Pinned so (the commit's choice: no rebuild in a fight).
