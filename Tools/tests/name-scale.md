# Name scale (Forever): test ledger
Goal: our names over heads are the size the game's own would be, at any zoom and distance.
Code: Plates/PlateParts.lua (Look, UNIT_YARDS, CLOSE_YARDS/FAR_YARDS), Core.lua plateNameClose*/Far* defaults, Dev/NameScaleTest.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Do the game's own names over heads grow as you walk up? | forever | YES, perspective: width ~ 3510 px / (camera-to-unit yd + 3.4) at 3440x1440, UI scale 0.64 (65 px at ~50 yd, 164 px at ~18 yd) | run 1 |
| Q2 | Does ours? | forever | NO: 181 px at every distance (zoom fixed at 12.3, Look gives 0.75) | run 1 |
| Q3 | Where do ours match the game's? | forever | only at ~16 yd from the camera (a unit ~4 yd from you); bigger than the game's everywhere else, 2.8x at 40 yd | run 1 |
| Q4 | Unit distance readable for a friendly NPC? | forever | bands only: CheckInteractDistance 4 (28 yd) and 3 (~10 yd) answered; UnitDistanceSquared nil | run 1 + rule forever.unit.checkinteractdistance |
| Q5 | Plate effective scale vs UI scale (does a UI scale change move our size vs the game's?) | forever | plate scale = UI scale. The game's names DON'T change with UI scale (201 px at 0.64 and 1.0); ours with the fix: 181 -> 180. PROVEN | runs 2-3 |
| Q8 | Does the fit hold with Shoulder Cam off / another FOV? | forever | Shoulder Cam off: ours ~162 px vs game ~198 by eye up close, same gap as with it on (ours ~10% small near: our guess 9 yd vs real ~6). FOV 90 in every run; other FOVs not tried (game's would shrink, ours not) | run 3 |
| Q9 | Smooth sizing looks smooth (SetTextScale between font sets)? | forever | NO: the user saw A (4% font steps) and B (eased text scale) the same; width changed in small moves (63 of 66 ticks) but letters draw at whole font sizes (rule all.fontstring.scale-steps-by-font-size). B kept: fewer font sets (6 vs 40 walking in). Next idea: crossfade two whole sizes | run 5 |
| Q10 | Does a plain SetFont at 0.1 steps draw bigger, or only at whole sizes? Same for SetTextScale and frame SetScale | forever | NO, all three snap the same, to whole-pixel font heights (size x 1.875 px rounded at UI 0.64 / 1440p): 7.0-7.1 251 px, 7.2-7.7 262, 7.8-8.0 282; 12.0-12.5 429, 12.6-13.0 449. Rule all.fontstring.scale-steps-by-font-size now tested. Only a crossfade can smooth | run 6 |
| Q11 | Crossfade looks smoother than steps, not soft/doubled? | forever | NO: doubled (mid-blend shot: the taller copy ~5% wider, outer letters a few px apart: "Stoommwind"); user picked A. Removed. Now whole-pixel steps held 0.15 px past half way against flicker | run 7 |
| Q7 | Ours grows walking in, smoothly, like the game's? | forever | grew 2.41x (game ~2.5x), width within 8% of the game's at 0-21 yd walked and at the end, BUT stalled at 19 yd (9 yd flat, -21% at 27 yd walked) then +43% at the 10 yd line. Fixed: on toward the band's far edge. Confirm: run 3 | run 2 |
| Q6 | Our name's height above the head vs the game's | forever | WRONG fit after run 2 (screen heights compared across the paused and running walks, camera not the same): far names fell to the unit's waist (run 3, user: "positions really bad"). By the gap over the head: game ~9 px far, ~15 at 18 yd; old y -26 gave ours 7-16 px higher; run 3 y -42 up close matched. Now -45 close to -38 far (V3). Confirm: run 4 far + near still pairs | runs 2-3 shots by eye |

## Built (after run 1, user picked "calibrate + grow")
- Size: one over (camera to unit + 3.4 yd), close point 8 yd = 1.3, far 50 yd = 0.27 (Core defaults; migration nameScaleV1 clears old saved ones).
- Unit distance per name: band from CheckInteractDistance 3/4 every 0.25 s out of fights (kept in fights), eased: to the band's edge at 15 yd/s, then toward its middle at your own speed (GetUnitSpeed). Size in 4% steps.
- Height (after run 2): same per-unit camera distance as the size, close Y 7, far Y -86; migration nameScaleV2 clears saved heights too.
- UI scale: size and height times 0.64 / UI scale (plates follow the UI scale).
- Easing (after run 2): after crossing into a band it heads for the band's far side (walking in: toward 10), not the middle.
- Offline: Tools/offline/namescale.lua (forever + retail) ALL PASS; migrate-test on the real saved file OK.

## DECISION after run 8 (full): zoom only
The user: "if I have to see the text go from font size to font size every second I will throw this out" / "the previous system was good but maybe just needed some more fine tuning". Per-unit distance sizing removed (bands, easing, PlateNameReach). Size = zoom + UNIT_YARDS 16 on the measured curve (close 1.3 at 8 yd, far 0.27 at 50, PAD 3.4), heights -45/-38, UI-scale fix, whole-pixel steps held PIXEL_HOLD 0.35 px (zooming only). Offline: no resize in 10 s at one zoom; zoom 2->30->2: 8 out / 6 back font sets, all whole pixels, no flicker; hovering: 0 flips. Run 8 (full): no errors, user picked B (whole pixels) over A; its A/B verdict FAIL was the test's (A's first sample before A's setting).

## Whole pixels (after run 7): crossfade removed (doubled); size set on whole-pixel heights, held PIXEL_HOLD 0.35 px past the half way so a hovering size doesn't flip; offline: 8 font sets walking in, 0 flips hovering (6 without the hold).

## Crossfade (after run 6, user picked it; REMOVED after run 7)
- The game draws whole-pixel heights only (run 6). The text is set at the pixel height just under its size; a copy one pixel taller (the ghost) fades over it: copy full by half way, text fading after half way, so one is always fully drawn. Off with a name fill on. Text-scale path removed.
- Offline (Tools/offline/namescale.lua, zoom 8): every font set at a whole pixel, never dimmed, blend under 0.088 a frame, no pops at a new pixel, 9 font sets walking in.
- Q11: does it look smooth (not soft or doubled)? run 7 A/B + a mid-blend screenshot.

## Smooth sizing (after run 4, user: "going from one size to another is ugly")
- Size eased toward its goal over 0.3 s (SMOOTH); small changes through FontString:SetTextScale over the font last set; font set anew only past 25% (SCALE_ROOM) or a new row look; a new height alone re-anchors without a new font.
- Offline: walking in, under 1.5% a frame, 6 font sets (old way: 40). Q9: does SetTextScale look smooth in game (or snap to whole pixel sizes)? open, run 5 A/B.

## Fit (run 1)
Pure calibration of the current model (fixed 16 yd guess): size(yd) = 14.6 / (yd + 3.4), so close (16 yd) 0.75, far (50 yd) 0.27 (now 1.6 and 0.3).
Ours then matches the game's for a unit ~16 yd from you; still the same size as you walk up (the game's grows ~2.6x over 40 yd).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug namescale | Q1-Q4 | Q5 not logged; Q6 shots not lined up by height. Test fixed after: box was in every shot (hidden the same tick), dev error window covered the NPC at the start |
| 2 | 2026-11-23 | /cine debug namescale | Q5 (plate = UI scale), Q7 grows (PASS 2.41x) | Q7 stall and Q6 height found from its shots: fixed after; game's names vs UI scale never changed in the run |
| 3 | 2026-11-23 | /cine debug namescale | Q5, Q8 (Shoulder Cam), grew 2.51x (PASS) at zoom 6.9 | heights wrong (run 2's fit); the test's red "stopped/resumed" lines read as errors; shot files a second off the logged time. Test fixed: quiet pause, saved file names, far + near still pairs, UI/cam steps proven (full only) |
| 4 | 2026-11-23 | /cine debug namescale | Q6 + Q7 CONFIRMED: far pair same size, ours ~3 px higher; near pair same height, ours ~7% narrower; grew 2.42x at zoom 8.5; no errors (quiet pause works). Calibration done | the "saved" file time can still be a second off the file (065829 vs 065828): take the nearest file |
| 5 | 2026-11-23 | /cine debug namescale | Q9: user "same"; no errors | why: text scale snaps to whole font sizes like SetFont; the logged width (GetStringWidth x GetTextScale) isn't what's drawn, so it couldn't tell |
| 6 | 2026-11-23 | /cine debug fontstep | Q10: STEPS for font, text scale and frame scale alike | analyzer first looked in Cinematic.lua (dev copy saves CinematicDev.lua): fixed; the text 7.0 cell measured a stray edge (345 px), the game's read agrees with the rest |
| 7 | 2026-11-23 | /cine debug namescale | Q11: crossfade doubled, user "A smoother"; no errors | the end of smoothing: whole-pixel heights are the game's limit |
| 8 | 2026-11-23 | /cine debug namescale full | all steps ran, no errors; grew 2.17x; user B over A | the user rejected per-distance resizing: zoom only now. A/B verdict FAIL was the test (fixed by removing the A/B) |
| 9 | 2026-11-23 | /cine debug namescale | CONFIRMED zoom only: one size (0.476) the whole walk (PASS), no errors; far pair (~16 yd) same size and height as the game's; near ours ~70% of the game's, by design (zoom only) | done |
