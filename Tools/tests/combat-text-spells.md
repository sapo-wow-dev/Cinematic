# Combat Text Spells tab: test ledger
Goal: a spell on Combat Text Style's Spells tab draws its hits in its own look in fights
Code: Style/CombatTextStyle.lua (OnCastEvent, TakeCast, OnHit), Style/CombatTextTexts.lua (CT.NoteSeen), Style/CombatTextSpells.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Casts made with Combat Text Style off, then the page on (no /reload): does a Shadow Bolt still grow and show its Spells look? (card 2026-11-25-combat-text-casts-off) | both | open | offline: combattextcastsoffmatrix.lua |
| Q2 | A physical ability (Mortal Strike, Sinister Strike, a cat's Claw) on the list: does its hit draw in its look, and a white swing not? Does it come under "Your spells that hit"? (card 2026-11-25-combat-text-ability-cast) | both | open | offline: combattextabilitymatrix.lua |
| Q3 | An area ability (Cleave, Whirlwind): every hit in its instant in its look? | both | open | not offline (one plate in the matrix) |
| Q4 | A heal added from the spellbook (Healing Wave): after one heal on a friend's plate, under Heals, its preview a heal? (card 2026-11-25-combat-text-seen-kind) | both | open | offline: combattextseenkindmatrix.lua |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
