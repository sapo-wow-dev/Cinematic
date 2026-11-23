# Zone card gap: test ledger
Goal: one place name on screen, never the game's zone line over a Zone card that's still up.
Code: Visions/ZoneCard.lua (Card: the gap branch), Dev/ZoneCardTest.lua step 8, Tools/offline/zonecardgame.lua 3b

Player case 2026-11-23 (Forever, v2.1.24, ElvUI): at Darrowmere Lake (the border of both Plaguelands) the
game's "WESTERN PLAGUELANDS" showed above our card. Cause: bdb2e1d (v2.1.24) shows the game's lines when no
card comes, including a card blocked by "Not again within" while the last one is still up. Fix e202b4a.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Within the gap, the last card up: the game's line stays hidden? | both | yes offline | zonecardgame 3b; zcgap stand-in run (step 8 checks 1-4 PASS) |
| Q2 | Same in game, the game's frame shown by FadingFrame_Show from our code? | forever | YES | run 1: alpha 0.00 under the card, card shot shows our name only |
| Q3 | The card gone, within the gap: the game's line shows (bdb2e1d's rule kept)? | forever | YES | run 1: card gone, the game's line alpha 1.00 DRAWN |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug zonecard 8 | Q2, Q3: 6 PASS, errors +0, blocked +0; step 8 marked proven | none. Note: the second shot didn't catch the game's line (it had faded by the shot, 1.5 s pacing); the verdict reads it directly |
