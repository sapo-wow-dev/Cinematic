# Text on You page redesign: test ledger
Goal: the Text on You Style page with a live preview of you, status chips, Show in, three tabs and each kind's own look (Tools/self-text-page-plan.md).
Code: Style/SelfTextStyle.lua (engine: boards, kinds' parts, merge, at most, crits stay, across, shadow, fade, Show in, sounds), Style/SelfTextPage.lua (page), Dev/SelfTextPageTest.lua; offline: Tools/offline/selftextstyle.lua, selftextpage.lua, selftextpagetest.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | A PlayerModel SetUnit("player") in a frame of ours shows your character, back view? | forever | YES (model file 1000764, back view in the shots) | run 1 |
| Q2 | SetFormattedText("%s x%d", secret, n) on our text shows it? | forever | inferred YES (MSBT Forever does it, read 2026-11-21); offline proven | run 1 step 5 uses plain words; a real merge needs a fight (next run with one) |
| Q3 | SetTextScale on our FontString (Pop) | forever | tested (font-max-120: SetTextScale on top works) | rule / memory |
| Q4 | The preview's texts clipped to it | forever | SetClipsChildren NO (run 2); a ScrollFrame YES (run 3) | runs 2-3 |
| Q8 | Pop keeps texts a line apart; the game's look in the middle | forever | YES after the fixes (0.94 lines apart; 0 across) | run 3 |
| Q5 | GetFont on our own text gives the file back (plain) | forever | YES (LilitaOne-Regular.ttf read back) | run 1 |
| Q6 | Page, chips, tabs, kinds editor, drag: built and wired | offline | YES: 52 checks, 6 deliberate breakages caught | selftextpage.lua |
| Q7 | Engine parts (merge, most, sticky, shadow, fade, across, kinds' parts, Show in, sounds, ticks, boards) | offline | YES (first-text side bug found and fixed) | selftextstyle.lua |

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
