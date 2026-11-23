# Tooltips No wait for (quest mobs) in fights: test ledger
Goal: a quest objective mob's tooltip skips the After wait in a fight too, not only out of one.
Code: UI/TooltipParts.lua (SkipsWait, CandidateUnits), Visions/QuestMobs.lua (ns.IsQuestMob), Support/Questie.lua
Tests: Tools/offline/tooltipnowait.lua, /cine debug tooltipnowait (Dev/TooltipNoWaitTest.lua)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q0 | Out of a fight: the check works? | forever | YES: GetUnit gave "nameplate2" (hovered via the mob), IsQuestMob true by tooltip line type 8 completed=false | run 1 step 1 |
| Q1 | GameTooltip:GetUnit()'s unit readable for a mob in a fight? | forever | YES here: hovering the mob's plate in a fight gave "nameplate1", quest mob yes by it (old code too) | run 2 |
| Q2 | UnitExists / UnitGUID / UnitName("mouseover") readable in a fight? | forever | open | run 2 |
| Q3 | UnitIsUnit("mouseover", target / nameplateN) readable in a fight? | forever | open | run 2 |
| Q4 | C_TooltipInfo.GetUnit("mouseover") quest lines (type, completed) readable in a fight? | forever | open | run 2 |
| Q5 | Which route answers yes in a fight: mouseover, target, plate? | forever | open | run 2 |
| Q6 | In a fight, does the tooltip refill keep the After look? | forever | YES: held 3 s, full tooltip in the shot | run 2 |
| Q7 | The reported case | forever | the mob itself, in a fight, CineMode on (user). Not reproduced in run 3 with the same | run 3 |

## Plan tree
Q5 any route yes -> done (run 2 = confirm). All no: Q2 GUID readable -> remember answers by GUID before the
fight (already kept by IsQuestMob); GUID secret + Q3 no -> keep the last out-of-fight answer per tooltip
owner/mouseover until UPDATE_MOUSEOVER_UNIT. Q6 no (After look lost on refill) -> keep noWait across refills
when the name can't be compared. All read in run 1.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | queue qf8f1 | Q0 (step 1 PASS). Odd: PlateOfMouseover found no plate though GetUnit said nameplate2 | step 2 never woke: UPDATE_MOUSEOVER_UNIT never fires on leaving a unit (test bug). Plate token now read from UnitFrame.unit too; per-plate UnitIsUnit logged |
| 2 | 2026-11-23 | queue q2085 | Q1, Q6: in a fight the plate-hovered quest mob skipped the wait (route tooltip, old code too); 2 fills; the re-ask 0.5 s later had no unit (GetUnit nil, mouseover gone: the mouse had left) | Q7: the original case isn't reproduced. Mouseover/plate UnitIsUnit read false for every plate with the mouse off |
| 3 | 2026-11-23 | queue q8982 | CineMode on, mob body hovered in a fight: PASS, skipped by the tooltip's unit (nameplate5), look held 3 s; Effects never hid it | The reported case still not reproduced. Lead: IsQuestMob holds a no 30 s after two early reads (RECHECK_SETTLED). Dev-copy watcher logs `tooltip: No wait said no` when the tooltip lines say quest mob but the answer is no |
