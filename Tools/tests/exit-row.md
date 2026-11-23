# Exit CineMode Show in row: test ledger
Goal: Exit CineMode tab's boxes in two columns; "Use a Show in row instead" swaps them for a Show in row (cine:exit).
Code: Options.lua (Exit CineMode tab), Core.lua (exitByRow, cineExitAlways, ns.StaysInCombat, ns.ExitRowOn,
ns.WindowsExit, ns.NPCsExit, cineOffCode "row"), Frames.lua / UI/GridRows.lua / UI/Why.lua /
UI/PersonalResources.lua (stayInCombat reads via ns.StaysInCombat), item.usable on Show in rows.
Tests: Tools/offline/exitrow.lua (both clients, prerelease), Dev/ExitRowTest.lua (/cine debug exitrow).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Row on Now (ns.RowOnNow) right for a non-frame row? | both | yes, used by effects, cursor hide | existing code |
| Q2 | Row Always -> CineMode off, unticked -> back by itself | forever | open (confirm) | run 1 step 1 |
| Q3 | Two columns laid out, toggle + row below, greying both ways | forever | open (confirm) | run 1 step 2 |
| Q4 | Boxes ignored with the row on (fights stay, windows/NPCs/places/moving don't exit) | both | yes offline | exitrow.lua |

No game facts open: no probe run, run 1 is the confirm run.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug exitrow | Q3 yes (all layout + greying PASS, screenshots right); Q2 half: row Always takes CineMode off (code row, Why words right) | Q2 back: waited out Back into CineMode after (15 s): the row's end didn't count as a change like the boxes'. Fixed (ns.exitRowWasOn -> switchedOn) |
| 2 | 2026-11-21 | /cine debug exitrow | same FAIL (14 of 15 s) | run 1's fix (switchedOn) lasts one tick: back for a tick, then the next waited again (lastBusy = the /reload, 3 s before). Found offline (Tools/offline/exitrowtick.lua calls ShouldBeCinematic straight). Fixed: the row's end sets quickStart, which lasts till the next exit. Assumption that broke: offline exitrow.lua never ran the tick, so run 1's fix wasn't proven before run 2. |
| 3 | 2026-11-21 | /cine debug exitrow | (pending: confirm) | |
