# Left list folds: test ledger
Goal: a left list line with lines under it (Style, Style > Interface) opens on every click; the list is never made again in a fight.
Code: Options.lua (Fold, menu.FoldBeforeClick, PaintArrows PreClick hook), Dev/ListFoldTest.lua (/cine debug listfold), Tools/offline/listclick.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does the game's line click redraw the list only if the picked line is open / a parent was folded? | both | YES (control: Style open, no lines) | run 1 step 2, rule now tested |
| Q2 | Does our PreClick on the list's lines run before the game's OnClick (button:Click and a mouse click)? | forever | YES (hooked; folds before the pick, list made once per click) | run 1 steps 1, 3 |
| Q3 | With the fold in PreClick, do Style and its group show their lines on every click? | forever | YES, 3 rounds of 3 | run 1 step 3, screenshot WoWScrnShot_112126_124028 |
| Q4 | Nothing blocked by the clicks out of a fight? | forever | YES, blocked +0, errors +0 | run 1 |
| Q5 | List never made again in a fight (picks wait for the end)? | forever | yes | old listfold run 2026-11-20 (steps 5-9 kept) |

## Plan tree
Q1 yes + Q3 yes -> done; rule goes to tested. Q1 no (control draws the lines) -> the game differs from the source on Forever: read its list code from /cine log probe, rule changed. Q3 no with Q2 yes -> the redraw condition differs: log says "list made N time(s)" per click. Q2 no -> hook OnMouseDown instead (log says hooked false or open never flips).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug listfold 1 2 3 4 | Q1-Q4: 8 PASS, 0 fail | none for the fix. Taint count said nil: the scan was called without its label (test fixed). A real mouse click is the same PreClick > OnClick path, so no confirm run needed |
