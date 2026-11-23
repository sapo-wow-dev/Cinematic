# Vitals Vision low mana: test ledger
Goal: as your mana runs dry the screen drains to a gray-blue veil with dark edges (Vitals Vision's Mana tabs).
Code: Atmosphere/ManaVision.lua, Atmosphere/LowHealth.lua (tabs), Dev/ManaVisionTest.lua, Tools/offline/manavision.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Mana readable? | forever | NO, secret even out of combat | rule forever.unitpower.mana-secret |
| Q2 | Curve alpha from mana on our overlay, no error? | forever | YES | runs 2, 3 (error=nil, mode game) |
| Q3 | GetAlpha readable after a curve SetAlpha? | forever | NO, stays secret even after a plain SetAlpha | run 2 probe; rule forever.alpha.secret-sticks |
| Q4 | Pages: Health/Mana tabs, Style's Mana tab, clear of the rest | forever | YES | runs 1-3, shots |
| Q5 | Retail | retail | open (offline only) | - |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | q422e | Q4 (Vision tab) | stopped: the test compared a secret GetAlpha (Q3), the preview was measured against a 1x1 tab body |
| 2 | 2026-11-23 | q3a4b | Q2, Q3, Q4 | real-mana shot showed ~1% (Full 0): Full set to 90% |
| 3 | 2026-11-23 | qa73f full | all, 9/9 | retail not run (Forever session) |
