# Tint layer: test ledger
Goal: the tint colors the world, not what the game draws over it (names, damage numbers)
Code: Atmosphere/Tint.lua (CreateTint), Dev/TintLayerTest.lua, Tools/offline/tintlayer.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Where can a wash sit under nameplate names? | forever | only WorldFrame's own textures | rule forever.plate.draw-order |
| Q2 | Did moving the tint to WorldFrame (02d4df0) start coloring damage numbers? | forever | NO: every place colors them (WorldFrame texture BACKGROUND + OVERLAY, WorldFrame child, parentless frame all red numbers); the old UIParent frame sits over all of those | run 1 (qe41d) |
| Q3 | Any place keeps damage numbers clean? | forever | NO | rule forever.worldtext.under-every-wash |

## Plan tree
Q2/Q3 no -> no layer fix. Clean numbers under a tint need our own copy of them over the wash (Combat Text Style already draws its own) or a lighter tint. User's call.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | tintlayer (queue qe41d) | Q2, Q3 | the UIParent shot itself caught no number (between hits); the parentless frame, which also sits over WorldFrame, showed red ones |
