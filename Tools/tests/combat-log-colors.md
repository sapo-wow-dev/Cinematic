# Combat log line colors (Combat Text Style, whose hit): test ledger
Goal: your numbers over nameplates stop taking other people's hits as yours, by reading what kind each combat log line is from its color.
Code: Style/CombatTextStyle.lua (LineKind, OnLine, TakeLine, Fits; ns.CombatTextLines), Dev/LineColorProbe.lua, Tools/offline/linekinds.lua, Tools/offline/linecolors.lua. Plan: Tools/combat-log-color-plan.md

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Blizzard_CombatLog_Filters readable in game, plain? | forever | YES | run 1 (rule forever.combatlog.line-color-from-filter) |
| Q2 | Line colors = the current filter's event colors? | forever | YES, 12 of 12 (spell, tick, kill) | run 1 |
| Q3 | Default My actions filter tells kinds apart? | forever | NO, one grey | combatTextLog 2026-11-19 |
| Q4 | Swing / swing-miss line colors as the filter says? | forever | open (inferred from Q2; a caster ran run 1) | run 2 if you melee, else stays inferred |
| Q5 | The page with step 1 skips the kill line, every hit of yours still drawn, no errors? | forever | YES for kinds and drawing (20 lines all known, 20 drawn, 0 left out); kill skip not reached in game (no kill line came), proven offline | run 2 |
| Q6 | Pet lines come under a filter listing your pet (MSBT's)? Then the page draws pet hits as yours? | forever | YES: Firebolt hits 0.13-0.39 s after the imp's cast took lines, drawn as yours (PET'S 0) -> 1b built | run 2 |
| Q7 | Reading the filter in a fight: errors, taint, BLOCKED? | forever | NO errors, 0 BLOCKED | run 2 |
| Q8 | 1b: imp hits drawn as your pet's, your own spells and ticks still yours? | forever | YES: 8 called your pet's, 8 look like its by timing (10 casts); wand (Arcane) hits stay yours | run 3 |
| Q9 | Replayed history lines (Oldest order) counted by the page? | forever | YES, a bug: 133 counted vs 44 real; fixed (skipped), offline linekinds 10 | run 3 |

## Plan tree
- Q5 PASS -> step 1 done; the Experimental notice stays until a group run (others' hits). FAIL -> the run's page lines show which pairing went wrong; fix from the log.
- Q6 pet hits take lines (drawn as yours) -> step 1b: a hit right after your pet's cast finished, in your pet's school, goes to the pet's row even with a line (needs: gap pet cast -> its hit, logged in run 2). No pet lines -> as today (PET'S path).
- Q4 swings: if a melee run happens, check SWING colors; else the filter's own colors stand (Q2).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug linecolors | Q1, Q2 | Q4 (caster), Q6 (pet hits not told apart in the probe's own pairing) |
| 2 | 2026-11-21 | /cine debug linecolors | Q5 (but the kill skip), Q6, Q7 | kill skip: no kill line that fight (offline proven; run 3 says SKIP if again); Q4: caster again. Test fixed: hits deduped per school, kill-not-reached says so, pet verdict added |
| 3 | 2026-11-21 | /cine debug linecolors | Q8; kill skip (3 kill lines, skipped); found Q9 | Q4 swings (caster). Page FAIL verdict was the Oldest-lines count, not step 1. Test fixed: counts old lines. No run 4: the Oldest skip is the same pattern both other addons use and is proven offline; it shows in the next normal run of the probe |
