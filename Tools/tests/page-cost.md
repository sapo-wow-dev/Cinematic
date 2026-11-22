# Settings pages cost: test ledger
Goal: know what the settings pages cost at login in game (memory, time, frames), to decide whether more pages should be made on first open (Options.lua lazyPages).
Code: Options.lua (ns.settingsPagesBuilt: the login build's ms + Lua KB per lap; ns.lazySettingsPages), Dev/PageCostTest.lua, Tools/offline/pagecost.lua, Tools/offline/pagecosttest.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | GetAddOnMemoryUsage readable, after a collect? | forever | YES: 61.3 MB with everything loaded | loadvisions runs 2-3 (Tools/tests/load-visions.md) |
| Q2 | How much Lua memory does the login page build take, which pages most? | forever | 589 ms; 12.7 MB by count (undercounts: the collector ran inside, CombatTextStyle lap -17.9 MB) to about 22.5 MB by step 3: 30-55% of Cinematic's 41 MB. Heaviest: Advanced Frames (CreateExtrasPanel 3.5 MB, 48 ms), Addon Links 2.1, Style Themes 2.0, Chat 2.0, Graphics 1.4, Tint Style 1.2, What's new 1.0 (43 ms) | run 1 step 1, rule forever.memory.collect-count-during-load |
| Q3 | Share of the game's frames that are our settings pages? | forever | 7,381 of the game's 21,027 frames (35%), plus 32,598 textures/texts | run 1 step 1 |
| Q4 | Real memory and time per page made on first open? | forever | HUD 4.8 MB 135 ms, Nameplates 5.2 MB 104 ms, Nameplate Style 2.9 MB 44 ms, Hover Groups 0.1 MB: 13 MB, 288 ms already saved at login (Card Vision/Sounds not there: Visions left out on this character, 4 lazy pages) | run 1 step 2 |
| Q5 | KB per object in game? | forever | 0.56 KB per frame/texture/text (Lua only) | run 1 step 3 |

Widen the net: states: out of combat only (pages aren't made in fights; step 2 skips in one). Secrets: none read. Protection: kit counts deverror/BLOCKED per step; the Settings window isn't opened (opening it from code with the gamepad can log a blocked line). Clients: Forever (retail if asked). Cinematic's state: no setting changed; CineMode off by the kit. Cost: the test freezes a moment per page (garbage collects), and the built pages stay in memory till /reload. GetAddOnMemoryUsage counts Lua memory only: the game's own frame memory isn't in it, so the real saving would be larger.

Decision branch taken: big share (30-55% of Cinematic's memory, 589 ms of login) -> plan moving the heaviest login pages onto lazyPages, search list first.

## Plan tree
Q2/Q5 show the login pages are a big share of Cinematic's memory (say 10 MB+) -> plan moving the heaviest (Advanced Frames, Chat, Style pages) onto lazyPages, with a search list that doesn't need pages built. Small share -> leave the pages, look at update loops instead (Profiler page). Both answered by this one run.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug pagecost | Q2-Q5; 6 PASS 0 FAIL, 0 errors, 0 blocked; Visions left out (41 MB total) | none. Test improved: context says which parts are loaded; the login count's undercount said in the log |

Offline before run 1: `python -I Tools/offline/run.py Tools/offline/pagecosttest.lua`, both clients, 6 PASS 0 FAIL (stand-in: login build 32 MB of its Lua, Advanced Frames 9.7 MB of it; the 6 lazy pages 26.8 MB).
