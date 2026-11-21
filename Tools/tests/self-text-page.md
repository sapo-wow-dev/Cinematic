# Text on You page redesign: test ledger
Goal: the Text on You Style page with a live preview of you, status chips, Show in, three tabs and each kind's own look (Tools/self-text-page-plan.md).
Code: Style/SelfTextStyle.lua (engine: boards, kinds' parts, merge, at most, crits stay, across, shadow, fade, Show in, sounds), Style/SelfTextPage.lua (page), Dev/SelfTextPageTest.lua; offline: Tools/offline/selftextstyle.lua, selftextpage.lua, selftextpagetest.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | A PlayerModel SetUnit("player") in a frame of ours shows your character, back view? | forever | YES (model file 1000764, back view in the shots) | run 1 |
| Q2 | SetFormattedText("%s x%d", secret, n) on our text shows it? | forever | YES: a heal's secret words merged, "+32 x2" on screen | run 5 |
| Q3 | SetTextScale on our FontString (Pop) | forever | tested (font-max-120: SetTextScale on top works) | rule / memory |
| Q4 | The preview's texts clipped to it | forever | SetClipsChildren NO (run 2); a ScrollFrame YES (run 3) | runs 2-3 |
| Q8 | Pop keeps texts a line apart; the game's look in the middle | forever | YES after the fixes (0.94 lines apart; 0 across) | run 3 |
| Q5 | GetFont on our own text gives the file back (plain) | forever | YES (LilitaOne-Regular.ttf read back) | run 1 |
| Q6 | Page, chips, tabs, kinds editor, drag: built and wired | offline | YES: 52 checks, 6 deliberate breakages caught | selftextpage.lua |
| Q7 | Engine parts (merge, most, sticky, shadow, fade, across, kinds' parts, Show in, sounds, ticks, boards) | offline | YES (first-text side bug found and fixed) | selftextstyle.lua |
| Q9 | No Shoulder Cam (or Follow off): texts straight over you, not beside the middle | forever | YES (Follow off: -0.2 across, side 0; the Shoulder Cam itself was on: shift -244) | run 6 step 9 |
| Q10 | The real page's preview, on the page and docked: texts' layer its size, you in it, the mark on a text's start | forever | YES on the page, docked, and docked 1.42x bigger (mark within 1 px of the text, you not moved) | runs 6, 8 |
| Q11 | A kind's own look opens docked as a Look panel; tabs one page each; right-click the mark resets it | forever | YES | run 6 steps 12-14 |
| Q12 | The page off: you hidden under its off card (rule forever.playermodel.ignores-parent-alpha) | forever | YES (faded true, the off card's 0 four frames up; you back when on) | run 7 step 15 |

## Plan tree
- Q1 yes -> done. No (model empty) -> a portrait-style ModelScene or a silhouette texture; the board still works.
- Q4 no (texts outside the preview) -> clip with a child ScrollFrame.
- Q2: confirmed only on a real fight's merge: the next fight test (/cine debug selftextstyle) shows "x2" on real hits.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug selftextpage | Q1, Q5; 8 of 8 PASS, 0 errors | The shots caught the texts faded (the kit waits 1.5 s, texts lived 1.6 s): the test now makes them last 4 s and checks crits after the shot. The preview read small: SCALE 0.6 -> 0.9, you framed bigger (upper body, as the Shoulder Cam). Q4 not reached. Q2 needs a fight. |
| 2 | 2026-11-21 | /cine debug selftextpage | 8 of 8 PASS, the shots readable now; showed Q4 no, Pop piling, the game's look over you, texts starting high | Verdicts didn't look at spacing or the game's spot: added. Fixed: Pop's spacing (engine, the screen too), the game's look in the middle, a ScrollFrame to clip, the texts start lower (LIFT) |
| 3 | 2026-11-21 | /cine debug selftextpage | Q4, Q8; 8 of 8 PASS | Shots: texts cut at the left edge (you too far left: OVER_X -0.2 -> -0.1, a verdict for texts past the edges added), a staying crit under a hit (a lane for it, offline check), the screen shot black (the kit's backdrop behind a screen-wide frame: dropped). No run 4: all three are layout, proven offline (the edge verdict fails with you near the edge); the next normal run of the test shows them. |
| 4 | 2026-11-21 | /cine debug selftextpage | Confirm after f181a8b: 8 of 8 PASS, 0 errors; 0 texts past the edges, Bold 0.94 lines apart, the staying crit in its own lane, the game's look above your head, the screen shot readable | Only the merge on real (secret) hits is left: a fight |
| 5 | 2026-11-21 | /cine debug selftextmerge | Q2: 2 of 2 PASS, 0 errors; a heal merged out of combat (count 2, words and text secret, shown) | None: every question answered |

After run 5 (2026-11-21, user screenshot): with the page off, its off card faded the page and the preview's model of you still drew under it (rule forever.playermodel.ignores-parent-alpha). Fixed: the model hides while anything over it is faded; proven offline (Tools/offline/selftextpage.lua, a mutation fails it). Seen on the next opening of the page with it off.

Run 6 (planned, 2026-11-21): /cine debug selftextpage, 15 steps, nothing to do. Run 6 because the old steps drew a copy of the preview, not the real page: they couldn't see the docked window's size, the shared preview fit moving you and the marks, the Free side with no Shoulder Cam, or the off card (all found by the user's shots). Steps 9-15 open the real page and check it on the page and docked, a kind's panel, the tabs, the mark and the off card. Offline: Tools/offline/selftextpagetest.lua runs all 15 (the stand-in never resizes the preview: the resize is proven in selftextpage.lua, where breaking it fails).

Run 6 (2026-11-21): 14 of 15 PASS, 0 errors. Step 15 FAILED by the test: the preview was docked, outside the page's off card (alpha chain 1 1 1). Fixed: step 15 puts the preview back first. Step 11 never tried a bigger window (docked it was the page's size): it now drags the window 1.4x bigger (as its corner), refreshes (the Style previews' fit runs), and checks again, plus you not moved. Found: dragging the window scales the preview, not its size, so the user's shot was the shared fit moving you and the marks (zoomSkip stops it). Run 7 = confirm, not a new probe.

Run 7 (2026-11-21): 14 of 15 PASS, 0 errors; off now PASS. Docked bigger FAILED by the test twice over: the model's place compared exactly (-60.7000008 vs -60.7000084 after the 1.42 scale), and the preview kept playing in the wait, so the test's text was pushed above a sample, 18 px over the mark (the shot shows the mark under the texts). Fixed: a 0.01 tolerance, Play paused while it measures. Run 8 because the bigger-window check was new in run 7 and both its misses were the test's own; nothing on the page changed.

Run 8 (2026-11-21): 15 of 15 PASS, 0 errors, 0 blocked. Docked bigger: the mark 1 px from the text, you unmoved, the preview scaled 1.00 -> 1.42. Every question answered; runs used: 8.
