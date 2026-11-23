# Reset gives game settings back: test ledger
Goal: Reset Settings / Reset Everything leave the game's settings as yours (Damage numbers on your target above all), whatever of Cinematic's held them
Code: Core.lua (ns.RestoreCVar, ca8a9fb), Profiles/Profiles.lua (ns.ResetAddon, 553ff33); test Dev/ResetCvarsTest.lua (/cine debug resetcvars), offline Tools/offline/resetcvarstest.lua, matrix Tools/offline/cvarresetmatrix.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Right after the real Reset Settings (its reload not in that frame), Damage numbers are yours and no set holds them? | retail | YES: _v2 1 (yours), none held, nothing saved; a second later Combat text off held it again (0, yours 1 saved), as features run on till the reload | run 1 step 2 |
| Q1f | the same | forever | YES: as on retail (_v2 1, none held, nothing saved; Combat text off took it again a second later, yours 1 saved) | run 2 step 2 |
| Q2 | After the reset's reload, with Combat Text Style and CineMode's combat text off both holding them before, Damage numbers are yours? | retail | YES: _v2 1, no holder (the re-hold after the reset let go at the reload's logout, yours written) | run 1 step 3 |
| Q2f | the same | forever | YES: _v2 1, no holder | run 2 step 3 |
| Q3 | The test's copy of your saved settings brings your whole setup back (profile, profiles, every held or saved game setting yours as before)? | retail | YES: profile Shoulder Cam, 2 profiles, 63 game settings yours as before, no copy left | run 1 step 4 |
| Q3f | the same | forever | YES: profile Shoulder Cam, 3 profiles, 64 game settings yours as before, no copy left | run 2 step 4 |
| Q4 | Does the game reload before a 0-second timer (ReloadUI vs C_Timer.After(0))? | both | not needed: fix 1 makes the write-back moot either way | - |

## Plan tree (step 3)
Q1+Q2 yes -> both fixes proven in game; mark steps 1-3 proven, step 4 stays (it's the safety net). Q1 no (a set still held) -> another holder the reset doesn't know (logged by label): add it to the let-go. Q2 no with Q1 yes -> a logout or login step writes ours (logged a second later + step 3's holder): find which. Q3 no -> the diff line names each setting: put back by hand in that run, fix the copy before anyone runs it again.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug resetcvars (retail, Windrunner Spire, group of 5) | Q1, Q2, Q3 on retail: 11 pass, 0 fail, errors +0, blocked +0 (log Tools/tests/logs/2026-11-23-retail-resetCvarsTestLog-5b9d54f0.txt) | Forever (Q1f-Q3f): run on retail only. Steps not marked proven: they hang on each other (2 -> 3 -> 4), so the Forever run needs all four |
| 2 | 2026-11-23 | /cine debug resetcvars (forever, Stormwind, solo) | Q1f, Q2f, Q3f: 11 pass, 0 fail, errors +0, blocked +0 (log Tools/tests/logs/2026-11-23-forever-resetCvarsTestLog-ee20a3ba.txt) | none: every question answered on both clients; all four steps marked proven (a plain run now runs none; `full` runs them all) |

Engine rule added from run 1: retail.savedvariables.global-swapped-before-reload (Tools/engine/rules/ui-frames.lua).
