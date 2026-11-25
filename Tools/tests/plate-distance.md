# Smart rows within X yards: test ledger
Goal: any Smart row (Nameplate Style) limited to plates within / past X yards.
Plan: Tools/plate-distance-plan.md
Code: Core.lua (MarkRowSplit), Frames.lua (ns.UnitInBand, rings), Plates/PlateParts.lua (FittingRow), Options.lua (drawer)
Probe: Dev/PlateRingsProbe.lua, /cine debug platerings

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | CheckInteractDistance answers on plates out of a fight? | forever | yes, index 1/4 ~28 yd (target + plates) | rule forever.unit.checkinteractdistance; probe confirms per index |
| Q1 | same | retail | yes out of fights (index 2, 4) | rule retail.checkinteractdistance.blocked-in-combat |
| Q2 | CheckInteractDistance on plates in a fight? | forever | NO: plain on one enemy plate (run 1), but blocked 36 times in a later fight with a pet's plate up | qd5a0 / q472f (another session), rule forever.range.plates-in-combat |
| Q2 | same | retail | NO, blocked | rule retail.checkinteractdistance.blocked-in-combat |
| Q1 | (probe) | forever | YES on enemy and friendly plates, indexes 1-5 | run 2 |
| Q3 | Attack spell range on plates, out of a fight? | forever | YES plain on enemies (nil on friendly plates, as expected) | run 2 |
| Q5/Q6 | (helpful, warlock 12 has none with a range) | forever | open: needs a class with heals | a healer run, later |
| Q4 | Attack spell range on plates, in a fight? | forever | YES, plain (Fear 20, Shoot 30) | run 1 |
| Q3/Q4 | same | retail | in a fight: yes, ranged spell plain (target) | rule retail.spellrange.plain-in-combat; plates: run 1 |
| Q5/Q6 | Helpful spell range on friendly plates? | both | open | run 1 |
| Q7 | C_Item.IsItemInRange on plates, out of a fight? | forever | NO: nil on all plates for all 8 bag items. Items dropped (Forever) | run 2 |
| Q8 | same, in a fight | forever | NO: nil for all 8 bag items | run 1 |
| Q9 | Each interact index's yards | forever | 1 and 4: 20-30 (the ~28 ring, one answer); 2, 3, 5: always the same answer, under 20 (no spell under 20 on a warlock 12 to bound them below) | runs 1-2; lower bound: walk-in or a class with a short spell |
| Q10 | Spell rings nest? | forever | yes, 0 of 39 pairs broke | runs 1-2 |
| Q11 | Cost | forever | 0.006-0.008 ms per call; 15 checks on 2 plates 0.18 ms per pass | run 2 |
| Q10 | Spell rings nest (in 20 => in 30)? | both | open | run 1 step 2 |
| Q11 | Cost of a pass over 20 plates | both | open | run 1 step 2 |

## Plan tree
- Q2 yes (Forever) -> interact rings in fights on Forever; no -> spells only in fights (like retail).
- Q3/Q4 no on Forever -> rings out of fights = interact only (11/28, + whatever Q9 finds); in fights none: rows with X fall back to "can't say" (fit no plate) and the drawer says so.
- Q7/Q8 yes -> an item ring list measured later (walk-in, AggroTest trick); no -> items dropped from the plan.
- Q9 gives the interact indexes' yards; if a bracket is wide, the walk-in test pins it (only then).
- Q10 broke -> pick rings per unit kind (enemy/friend) and log which.
- Q11 over ~0.3 ms per pass -> per-pass cache is a must, and fewer rings per X.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-25 | queue q5e93 (Forever, warlock 12) | Q2 yes, Q4 yes, Q8 no; Q9 partly | step 2 waited for 3 plates (only 1 up; nameplateShowFriends doesn't exist on Forever, friendly plates are nameplateShowFriendlyNpcs/Players): fixed, waits for 1 and turns those on |
| 12 | 2026-11-25 | queue q76d2 (~30 yd, spell first; Forever) | ~30 = Shoot 30 in fights and out; 17/17 plates on the right row; drawer hint "30 yd" inside; fade eased | marks 0/17: CineMode was on (kit no longer forces it off) - test now turns it off for the Smart steps; "Within ~30 yards" and "Enemies within ~30 yd" cut short - now "Within ~30 yd" and "Enemies in ~30 yd"; a targeted mob counted as wrong - target left out; wandering mob: both ways also from the fade watch: run 13 q25e1 |
| 10 | 2026-11-25 | queue q44a9 (Forever) | FIGHT FIX PROVEN: a fight with a Smart row and Enemies in both on, 0 blocked actions, 30/30 plate asks answered by spells | fade step: both mobs past the warlock's 30 yd, no reach; now waits for one in reach: run 11 q313a (fight step proven) |
| 9 | 2026-11-25 | queue q772a (fade, Forever) | the plate eased in at 30 yd; 10/10 right | the mob walked in, nothing crossed at 28 and it read as a jump (test now picks short at the switch and judges only moves). Also: another session found 36 ADDON_ACTION_BLOCKED in one Forever fight from CheckInteractDistance on plates (qd5a0, q472f): Q2 is NO after all. Interact never asked in fights now; new step 5 fights with both on and fails on any block: run 10 |
| 7 | 2026-11-25 | queue qa2ae platerange step 4 (Forever) | Enemies within: 10/10, shown at 30 yd (5), hidden at 28 yd (5) on the same mob, by the row; box says 20 | the label's "yd" ran into the Always column's dot. Label now "Enemies in" (Why still says Enemies within), verdict yd ends before the row's grid; sampling proven: run 8 qa53e layout only |
| 6 | 2026-11-25 | queue q781d platerange step 4 nearby (Forever) | CineMode on; 9/9 enemy looks right (one enemy, past 20 yd: hidden) | "shown when near" never seen (no enemy within 20) and the yards box not in view (page opened scrolled away). Test now sets the row's yards past then short of the nearest enemy (both ways, no walking) and opens the page at plateNearbyYards (box given settingKey): run 7 qa2ae |
| 5 | 2026-11-25 | queue qc8fe platerange (Forever) | 13/13 PASS: 19/19 plates on the right row, marks drawn 19/19, hint "20 yd" inside the drawer (971 of 979), no dropdown cut short, retype to 24 keeps the look. Forever DONE | retail not run; a red glow on a red health bar is hard to see on the shot (look choice, not a bug) |
| 4 | 2026-11-25 | queue q7875 platerange (Forever) | 10 PASS: marks drawn on all 10 plates, rows right 10/10, yards box covers nothing | 2 FAIL: the "= 20 yd" hint ran 26 px past the drawer. Hint now "20 yd" (fight yards in the tip, * when they differ), box 30 wide, Type and Distance dropdowns 10 narrower, plus a no-dropdown-cut-short verdict: run 5 qc8fe |
| 3 | 2026-11-25 | queue q88d3 platerange (Forever) | 8/8 PASS: rows fit by distance (9/9), never both, 40 asks 0.155 ms, yards box + "= 20 yd" hint, typing 24 retypes with its look | marks not seen on the shots: the test left the rows' When unset (page said Never), and r:Overlaps' answer wasn't checked. Fixed in the test (When Always, mark drawn verdict, overlap + right-edge verdicts): run 4 q7875 |
| 2 | 2026-11-25 | queue q3874 (Forever, warlock 12, 2 plates) | Q1, Q3 yes; Q7 no; Q9 to brackets; Q10, Q11 | Q5/Q6 (no heals on this class), Q9 lower bound for 2/3/5, every retail question |
