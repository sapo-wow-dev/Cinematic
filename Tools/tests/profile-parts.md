# Profiles leave out Visions and Cameras: test ledger
Goal: picking Auto-Hide UI or Blank Slate unticks Load Visions + Load Cameras + Load Style (2026-11-22) and asks to reload with the Load boxes' own Reload box (same box, same words, the game's spot); another built-in ticks them back; Reload UI in that box really reloads into that state.
Code: Modules.lua (ns.AskModulesReload: the one Reload box), Profiles/Profiles.lua (ns.ProfilePartsPicked), Profiles/ProfileChoices.lua (leaveOut), Profiles/Welcome.lua, Options.lua (Load box + Profiles page), Slash.lua (/cine profile), Dev/ProfilePartsTest.lua, Tools/offline/profileparts.lua + modules.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Picks set the Load boxes; the box asks / goes as it should | both | YES offline; YES in game (welcome card + /cine profile) | modules.lua, profileparts.lua; run 1 |
| Q2 | Where should the box sit with the welcome window open? | forever | The game's own spot, as every Cinematic Reload box (Edit Mode's, the Load boxes'): user, run 1 ("look at where we display it for others"). Own spot under the window = FAIL | run 1, user's screenshots |
| Q3 | The game's spot clear of the welcome window (CENTER +60)? | forever | YES on 3440x1440 at 0.64: box 627-682, window 253-591 (StaticPopup1, TOP UIParent TOP 0 -135, DIALOG; shots) | run 3 steps 2-3 |
| Q4 | Reload UI in the box reloads (run 3: up to 3 clicks) (Forever: secure cover over the button) | forever | YES: three clicks on Reload UI, each reloaded (8-10 s), cover=true each time | run 3 steps 1-3 |
| Q5 | After that reload: both left out, defaults copy kept, still Auto-Hide UI; back the other way | forever | YES: left out (pages gone, defaults copy kept, still Auto-Hide UI), then back (pages back, copy gone, on Balanced) | run 3 steps 3-4 |
| Q6 | Every box clear of the welcome window, whatever its height or where you dragged it | forever | YES run 4: window put high (top 730) moved under the Reload box (575 under 580) and under the Edit Mode box (614 under 620), back to 730 once gone; with a group invite up first the game stacked ours under it (StaticPopup2) and the window went under both. User's screenshots after run 3: the Agree box above the window, the Reload box on its title: same game spot, the window's top moved (CENTER anchor, shelf height, drags). Now Welcome.lua KeepUnderBoxes moves the window under any box, back after (offline YES with pretend places) | run 4 steps 2 + 4 (window put high) |

## Plan tree
Q3 no (overlaps on a small screen) -> move the welcome window, not the box (the game's boxes stay in sync). Q4 no -> the cover (QoL/Reload.lua) misses on this box: check `cover` field + Reload.lua's StaticPopup_Show hook. Logged in run 2.

Q1-Q5 done in 3 runs (run 2 wasted by the test: no start-state step). Q6 found after: run 4; Style added and confirmed in run 5 (the user's screenshots, not a test miss: no run put the window high).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug profileparts | Q1 in game (20 pass); Q2: own spot rejected by the user | Q4/Q5: the run never clicked Reload (test's fault: it asked a question instead); now it goes through the real button both ways |
| 2 | 2026-11-22 | /cine debug profileparts | nothing: both already left out at the start (saved loadVisions/loadCameras = false at the 00:25 reload), the pick changed nothing, no box, and step 1 waited on a Reload click with no box (user: "what am i doing here?") | test's fault: no start-state step, a wait with no box. Now step 1 loads them first through the box (also proves Reload UI), and a missing box FAILs instead of waiting |
| 4 | 2026-11-22 | /cine debug profileparts | Q6: 50 pass, 1 fail (test's: "at the game's spot" wanted StaticPopup1, a group invite was up first: now accepts under another game box) | Style added to both profiles after this run: not in game yet |
| 5 | 2026-11-22 | /cine debug profileparts (Visions, Cameras, Style) | all, Style too: 59 pass, 0 fail, errors +0, blocked +0; three Reload UI clicks; window under the box (622 under 627) and back | words read "a and b and c": now "a, b and c" (Modules.lua; offline checks the exact text). Not worth a run of its own: shown in the next run that touches the box |
| 3 | 2026-11-22 | /cine debug profileparts | Q1-Q5: 47 pass, 0 fail, errors +0, blocked +0 | none. Not in game: the Profiles page click (same helper, offline-checked); retail (not asked) |
