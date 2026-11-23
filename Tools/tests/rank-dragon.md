# Rank dragon on a theme's portrait: test ledger
Goal: the elite, rare and boss dragon sits round a Style theme's portrait shape and grows with it (Discord 2026-11-23).
Code: Style/UnitStyle.lua (PlaceRank, WatchRank, DressShape); offline Tools/offline/rankdragon.lua; game Dev/RankDragonTest.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Where does the game put the dragon? | both | TOPRIGHT of TargetFrameContainer at atlas size; Forever rare +8,-7, boss +11,-4, elite 0,+1 | rule ui-frames (target art), game source TargetFrame.lua:419 |
| Q2 | Re-anchored to the portrait's middle, grown: offsets right? | both | offline yes (stand-in sizes) | Tools/offline/rankdragon.lua 27/27 both |
| Q3 | Does it look right round each shape (art's ring vs ours)? | forever | YES: petal, circle, arch each wrapped like the game's ring | run 2 shots 13:54:55-13:55:37 |
| Q4 | Atlas sizes per dragon | forever | rare winged 109x88.5, boss winged 110x90, elite 100x100 | run 2 step 1 |
| Q5 | Texture SetPoint on the target's art blocked in fights? | forever | unknown, not probed (no fight in this run; textures aren't protected) | - |

## Plan tree
Q3 looks centered -> commit. Looks off by a fixed amount -> the art's ring isn't at its middle: per-dragon nudge from the shots' reference (game look). Q4 logged so a nudge can be sized without another probe.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | queue q46a0 (rankdragon) | nothing: setup PASS only | cut off at the target wait (a logout at 13:50, no target given); not the test's fault. Queued again as qaed1 |
| 2 | 2026-11-23 | queue qaed1 (rankdragon) | 36 pass 0 fail, errors +0 blocked +0; Q2-Q4 | retail not run (offline only); fights not probed (Q5) |
