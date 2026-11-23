# /cine find results window: test ledger
Goal: /cine find <words> lists every match ranked (typos, plurals, page paths, synonyms), picked from a window
Code: UI/Find.lua, Options.lua (BuildSearchIndex, FindSetting, search box Enter), Slash.lua, Dev/FindResultsTest.lua, Tools/offline/findrank.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Heal Vision page in the search list in game? | forever | YES (106 pages, Visions loaded) | run 1 step 1 |
| Q2 | Ranking on the game's frames as offline? | forever | YES, 12/12 | run 1 step 2 |
| Q3 | Search fast enough? | forever | index 1288 ms first time (lazy pages made), rank 31-292 ms | run 1 step 2 |
| Q4 | Window on screen, rows inside? | forever | YES | run 1 step 3 + shot |
| Q5 | Window stays when a result opens the settings? | forever | NO: settings open runs CloseWindows (rule all.settings.open-closes-special-frames); fixed: shown again after | run 1 step 4; confirm run 2 |
| Q6 | Typed words + Enter open the best? | forever | YES | run 2 step 5 |
| Q7 | Docked window clear of the settings? | forever | Was NO with the settings right of the middle (3440 wide). Fixed: DockBeside docks left when the right has no room; YES, gap 3, no overlap | run 2 shot; run 4 |

| Q8 | New look in game: icons load, titles fit, fold opens on a real click, bar inside right of the lines, no empty band | forever | YES | runs 6-7 step look |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug findresults | Q1-Q5 | Q6: the window was closed by Q5 |
| 2 | 2026-11-23 | /cine debug findresults | Q5 fixed, Q6, Q7 found | Q7's fix: needs the confirm run |
| 3 | 2026-11-23 | /cine debug findresults full | steps 1-3, 5 again: 23 pass | Q7: the game hadn't reloaded since the fix (session 06:05:57, edits 06:06) |
| 4 | 2026-11-23 | /cine debug findresults | Q7: 5 pass | none: every question answered |
| 5 | 2026-11-23 | /cine debug findresults full | steps 1-2 again (12/12), step 3 four checks | Q8: the TEST stopped at step 3 (an emptied line text read nil in format; rule all.fontstring.empty-text-nil). Wasted by the test; the stand-in now gives nil too |
| 6 | 2026-11-23 | /cine debug findresults full | Q8 mostly: icons, no cut titles, unique titles, fold opens on a click, bar inside, 14 px under the last line; 36 pass | the test's Down-twice check started from the fold's line (a click picks it): fixed; '?' icons on Keybinds/Profiles lines and a dim best-line text seen in shots: fixed |
| 7 | 2026-11-23 | /cine debug findresults | Q8: 12 of 12, Keybinds/Profiles lines with Cinematic's icon (shot) | none: every question answered |
