# Allow offscreen nameplates in CineMode: test ledger
Goal: Settings > General's Auto / Always / Never decides whether CineMode holds the game's Show Offscreen Nameplates on; Never leaves yours alone.
Code: Effects.lua (ns.plates.OffscreenWhy, OFFSCREEN_PLATE_CVARS), Options.lua (dropdown), Migrations.lua (old tick -> Always), Core.lua (default never)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | nameplateShowOffscreen exists and sets out of a fight? | forever | YES | run 1, rule forever.plate.show-offscreen-cvar |
| Q2 | Never: not turned on, and a player's own 1 stays 1? | forever | YES | run 1 steps 2-3 |
| Q3 | Always: on in CineMode? | forever | YES | run 1 step 4 |
| Q4 | Auto: on only for Emote Vision's cards / Heal Vision? | forever | YES (cards) | run 1 step 5 |
| Q5 | Auto: let go with an attackable target, back once cleared? | forever | YES | run 1 steps 6-7 |
| Q6 | Auto: off in a city unless rows take cities in? | forever | YES (simulated city) | run 1 step 8 |
| Q7 | Player's setting back after CineMode? | forever | YES | run 1 step 9 |
| Q8 | Choices, migration, Reset, /cine find | both | YES | offline Tools/offline/offscreenallow.lua 20/20 |
| Q9 | Same on retail? | retail | open, not asked for | only if the user brings it up |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug offhold | Q1-Q7, 10 PASS 0 FAIL, no dev errors or BLOCKED | Q9: Forever only (retail not asked) |
