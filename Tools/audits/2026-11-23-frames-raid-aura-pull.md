# Frames: raid auras on for a fight the raid row shows in (fix card)
Fix: on WoW Forever, since v2.1.24 (bdb2e1d), a raid Buffs or Debuffs row that's faded before a fight and comes up for it (CineMode off or leaving for the fight, or the row's In combat) kept the game's raid auras off for the whole fight: the switch waits out fights, and the row fades again before it ends.
Found by: card audit of the v2.1.24 audit fixes, 2026-11-23 (finding 1); the user: "Fix 1, 2, 3"
Code: Frames.lua: auraStandIns.ShowsInFight (new), the group watch (PLAYER_REGEN_DISABLED: auras on before the lockdown)
Clients: forever (retail: no stand-in, the icons fade as parts)
Base: bab6823

## Before / after
- Before: in a group, raid Buffs row faded out of a fight. The pull: the row comes up (In combat ticked, or CineMode
  ends at the pull), but the game's raidFramesDisplayBuffs stays 0 all fight: no buff icons on the raid frames.
- After: at the pull (PLAYER_REGEN_DISABLED, just before the lockdown) the auras go on if the row will show in the
  fight; a row staying faded (CineMode on through fights, its In combat off) keeps them off. After the fight, as
  before: switched to what the row says then. No switch inside the fight (bdb2e1d's reason kept: each switch has the
  game rebuild its secure raid frames, CompactUnitFrameProfiles:ApplyCurrentSettings, from our call).

## Who relies on the old behavior
- Players: Forever group players with the raid aura rows faded out of fights and shown in them: they get their
  auras back in fights, as on v2.1.23 (which switched mid-fight).
- Other features: ns.ApplyCVarSet secure sets (Core.lua:3313, waits only in the lockdown); the Game Settings page
  (playerWins: unchanged); ns.Suspend's put-back (unchanged).
- Tests that encode it: raid-aura-standin cells (all unchanged); fightsfades check 3 (passes).

## States (the matrix)
raid-aura-standin as before (row x group x a change in a fight x held/free). New raid-aura-pull: CineMode on/off x
staying on in fights x the row's In combat (its rule), the row faded before and after the fight, in a group.
Test: Tools/offline/raidaurasmatrix.lua forever
Test: Tools/offline/raidaurasmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| raid-aura-pull | cine=off | during=0 after=0 | during=1 after=0 |
| raid-aura-pull | cine=on stays=no | during=0 after=0 | during=1 after=0 |
| raid-aura-pull | cine=on stays=yes tick=yes | during=0 after=0 | during=1 after=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (a new matrix part; the old cells and fightsfades unchanged) | | | | |

## Risk
low: Forever, in a group, once per fight start. Not proven offline: that RowOnNow reads the fight's facts at
PLAYER_REGEN_DISABLED (UnitAffectingCombat already true then), that the switch at that moment isn't blocked (the
lockdown not on yet), a Hover group bringing the row up mid-fight (still not switched in the fight, as bdb2e1d), and
Exit CineMode by a Show in row (ExitRowOn read at the pull). Needs one in-game fight in a group on Forever.

## Open
- user's call: a row brought up mid-fight by a Hover group still gets no auras till the fight's end (no switch
  inside a fight).
