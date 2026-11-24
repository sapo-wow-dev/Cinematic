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
| Q12 | ANSWERED run 11: the engine shrinks plates by camera distance (nameplateMin/MaxScale + distances); far names can shrink with their plates. Was: Far names: what do the game's own settings do (MaxUnitNameDistance, nameplateMin/MaxScale + distances, SoftTargetWorldtext*, WorldTextMinSize)? Do Forever plates shrink by distance with nameplateMinScale? | forever | open: /cine debug nameconsole (Dev/NameConsoleTest.lua): values, defaults, help; plates near/mid/far at min scale 0.5 | run 10 |
| Q13 | Far names smaller: held, one step (0.65), no gradual scales? | forever | YES: held with every value; past 28 yd 0.416 (= 0.65 x 0.64), nearer 0.640, no third scale; no errors. Shot showed no names (CineMode faded them): test keeps friendly names up for its shot now | run 12 |
| Q7 | Ours grows walking in, smoothly, like the game's? | forever | grew 2.41x (game ~2.5x), width within 8% of the game's at 0-21 yd walked and at the end, BUT stalled at 19 yd (9 yd flat, -21% at 27 yd walked) then +43% at the 10 yd line. Fixed: on toward the band's far edge. Confirm: run 3 | run 2 |
| Q14 | What makes names "jump" a little past 28 yards (user, 2026-11-23)? | forever | ANSWERED run 15: Far names smaller. Untargeted plate 0.64 -> 0.42 at 34.3 yd walked (zoom 5.2: ~39.5 from the camera), walk 1 only; with it off, 0.64 all the way; the user saw the jump in walk 1 only. Not ours: our size, height and alpha held through it. Fix: the user's call (below). Run 14 | forever | ANSWERED |
| Q16 | Far names smaller at min scale 0.8 (fix card 2026-11-23-far-names-step): walk 1 steps 0.64 -> ~0.51 once, at the same ~40 yd from the camera, and the user finds it gentle enough? | forever | CONFIRMED run 18: 0.64 -> 0.51 once, 33.9-34.8 yd at zoom 5.5, walk 1 only; the user still saw a jump (walk 1). Next: A/B dropdowns (Name size by zoom/fixed, Far names off/0.9/0.8/0.65), the user's call where | run 18 |
| Q18 | Standing still, does the zoom alone bring the far step on and off (the user: "i dont believe" it's the camera's distance)? | forever | YES, PROVEN zoomstep run 1 (q9686, Westfall, Farmer Saldean): you moved 0.00 yd at all 17 zooms; plate 0.64 -> 0.42 between zoom 4.0 and 5.0, held to zoom 15; Same size: 0.64 at every zoom. Shots WoWScrnShot_112326_165850 (zoom 4, full) / 165854 (zoom 5, small) | zoomstep run 1 |
| Q19 | Far names from YOU (our own step past 28 yards, the game's camera step let go): far names at the step of near ones, plates all one scale, zooming changes nothing? | forever | YES, PROVEN farnames 14 (q2ef9) + zoomstep 3 (q52c9), 2026-11-23: plates held one size (min = max = 1), every plate 0.64 but the target's, 6 far NPC names at 0.80 of near (0.762); standing still zoom 0-15: plate 0.64 and our name 0.476 the whole sweep, the control too. Left: the old distances still 41 / 5 (V1 cleanup skipped): V2 cleans them, offline only; farnames step 1 logs them | farnames 14, zoomstep 3 |
| Q17 | Name Style page's Size choices (Size by Zoom/Fixed, Far names Same size/0.9/0.8/0.65): on the page clear of the rest, greyed with the page off, each saved and Far names smaller following at once? | forever | open: /cine debug namesize run 1 (offline ALL PASS; layout and greying only in game) | namesize run 1 |
| Q15 | Our size 0.833 at the start, 0.884 -> 0.905 when the plate came back at 44 yd, same zoom 5.2: why? | forever | open (not the jump: a plate coming back into range; the start's 0.833 was while the target's 1.2x was easing off) | run 15 |
| Q14-old | Run 14 (targeted NPC, zoom 4.6): NOTHING on screen changed 0-58 yd: size 0.913 and y -42 held, plate scale 0.77 held (target plate never shrinks: rule forever.plate.selected-no-distance-scale); only the range band and sight check flipped at ~30 yd. Run 15: untargeted (plate found by GUID), usual zoom, out to 46 yd | runs 14-15 |
| Q6 | Our name's height above the head vs the game's | forever | WRONG fit after run 2 (screen heights compared across the paused and running walks, camera not the same): far names fell to the unit's waist (run 3, user: "positions really bad"). By the gap over the head: game ~9 px far, ~15 at 18 yd; old y -26 gave ours 7-16 px higher; run 3 y -42 up close matched. Now -45 close to -38 far (V3). Confirm: run 4 far + near still pairs | runs 2-3 shots by eye |

## Built (after run 1, user picked "calibrate + grow")
- Size: one over (camera to unit + 3.4 yd), close point 8 yd = 1.3, far 50 yd = 0.27 (Core defaults; migration nameScaleV1 clears old saved ones).
- Unit distance per name: band from CheckInteractDistance 3/4 every 0.25 s out of fights (kept in fights), eased: to the band's edge at 15 yd/s, then toward its middle at your own speed (GetUnitSpeed). Size in 4% steps.
- Height (after run 2): same per-unit camera distance as the size, close Y 7, far Y -86; migration nameScaleV2 clears saved heights too.
- UI scale: size and height times 0.64 / UI scale (plates follow the UI scale).
- Easing (after run 2): after crossing into a band it heads for the band's far side (walking in: toward 10), not the middle.
- Offline: Tools/offline/namescale.lua (forever + retail) ALL PASS; migrate-test on the real saved file OK.

## Sized for 8 yards (after run 12, user: "names are feeling a lot smaller than before")
UNIT_YARDS 16 -> 8: at zoom 10 a name is 0.69 (was 0.50 at 16; 0.85 before 2026-11-23); past 40 yd from the camera 0.45. Offline: zoom 2->30 font sets bounded by the pixel span now (bigger names cross more pixels). Confirm: /cine debug namescale (walk, near pair should now match the game's ~8 yd).

## Jump past 28 yards (Q14, plan tree)
Candidates: (a) Far names smaller's one plate step (Q13: 0.64 -> 0.416 past 28 yd); (b) PlateParts' sight check, asked only within 28 yd (CheckInteractDistance 4): a dimmed plate's name hides inside, stays past it; (c) the game's own plate alpha/scale.
- Plate scale steps in walk 1 only -> (a): move the step further out or soften it (nameplateMin/MaxScaleDistance), or drop it; then need: where the user wants far names smaller to start (ask), no probe.
- Our name alpha/shown changes at 28 -> (b): hysteresis around the 28-yd line in the sight check; offline check only.
- Scale step in both walks -> (c): the game's; log names the CVars at the time.
Ruler: `/cine debug namescale ruler` (free walk, no verdicts). Offline: Tools/offline/namejump.lua.

## Far names smaller (after run 11, user: "one step, far only")
Effects.lua ns.plates.FAR_NAME_CVARS "Far names smaller": nameplateMinScale 0.65, MaxScale 1, MaxScaleDistance 41, MinScaleDistance 5 (min from 45-5 = 40: the distances cross, so the game jumps in one step at ~40 yd from the camera). Held with every plate on (CineMode away from instances), Forever, Name Style on; kept through fights. Q13: does it step once at ~40 and nowhere else? /cine debug farnames (Dev/FarNamesTest.lua).

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
| 10 | 2026-11-23 | /cine debug nameconsole | values only: nameplateMinScale default 0.8 (yours 1), Min/MaxScaleDistance 10/10, nameplateMaxDistance 45, SoftTargetWorldtext Near 4 / Far 40 / Size 32 / NearScale 1, WorldTextMinSize 0, nameplateSize 3; MaxUnitNameDistance and nameplateShowFriends are not settings on Forever | test's fault: C_Console.GetAllCommands listed 0 (now ConsoleGetAllCommands), 0 plates read in Elwynn (now logs why, and waits for near+far plates) |
| 11 | 2026-11-23 | /cine debug nameconsole | Q12: plates DO shrink on Forever now (min scale 0.5: far 0.64 -> 0.32, our names with them); rule forever.plate.no-distance-scale changed. Help lines read (1876 commands): MaxScaleDistance from the camera, MinScaleDistance back from nameplateMaxDistance 45; WorldTextMinSize = "smallest size used for world text like player names" (0); MaxUnitNameDistance not a setting | which distances give one clean step (not a gradual scale: whole-pixel pops) not yet mapped |

| 12 | 2026-11-23 | /cine debug farnames | Q13 answered: one step works | the screenshot couldn't show names (faded): fixed for any later run |

| farnames 13 + zoomstep 2 | 2026-11-23 | queue qbe65 + q9253 (Goldshire / Elwynn) | our step works: far NPCs' names 0.595 vs near 0.762 (0.78); BUT the game's camera step still came (zoom 6-7, 0.64 -> 0.51, the control too): its CVars were left at 0.8 / 41 / 5 with no saved value of yours, and the game's own default (min 0.8, 10 / 10) scales by the camera too | farnames: the test's fault, every name "not shown" (Call passed 3 of 5 returns) so step 1 never went on (user ISSUE); zoomstep counted a stale size at zoom 0. Fixed after: plates held ONE size in CineMode (min = max = 1), leftovers 41 / 5 put back once, tests fixed |
| namesize 1 | 2026-11-23 | /cine debug namesize (queue qb24b) | each pick works in CineMode: Far names 1 lets go (game's 1), 0.9/0.8/0.65 held at once (game's the same); Size by saved | layout: the checkbox choices wrapped and sat on the row above (3 of 6 overlapped, shot 163802): now joined buttons (rows.Segments). "0 of 6 greyed": the test's fault (no page redraw after r:Set): it redraws now |
| 18 | 2026-11-23 | /cine debug namejump (queue q3e81) | DONE 4 pass: Far names smaller at 0.8 steps 0.64 -> 0.51 at ~34 yd (zoom 5.5), gone with it off; our size held; edge fade-out at 45 yd as before; user: jump seen in walk 1 | done |
| 17 | 2026-11-23 | /cine debug namejump (queue q3352, REQUEUED by the user in walk 1) | setup's "waiting for" worked (a target, then 2 s still) | the test's fault: Steven Black's name showed only while targeted (ours hid at Escape), so walk 1 had nothing to watch. Fixed: after Escape, our name must show; else "pick ANOTHER" (3 tries) |
| 16 | 2026-11-23 | /cine debug namejump (queue q81df, STOPPED + ISSUE) | nothing: setup never saw its conditions met | the test's fault: its check never said which one was missing. Fixed: the box shows "Waiting for: ..." live, each change logged, within 11 yd counts too |
| 15 | 2026-11-23 | /cine debug namejump (queue qb14b) | Q14: Far names smaller's step, 34.3 yd at zoom 5.2, walk 1 only; user: walk 1. Also: plate dims to 0.6 past 29 yd (occlusion, known), every plate shrinks/fades away past 45 (nameplateMaxDistance) | the test's two wrong lines, fixed after: "size held" FAILed on float noise and a plate coming back; "cause" said "on AND off" from the plate coming back (nil -> 0.64) |
| 14 | 2026-11-23 | /cine debug namejump (queue q883f, CUT-OFF at the last question) | the TARGET's name never jumps (zoom 4.6, 0-58 yd); target plate isn't shrunk by distance (new rule) | the test's fault: it watched the target, whose plate never takes the far step; zoom 4.6 puts the step at ~36 yd, past its 24-36 window; our/game alpha read nil (GetEffectiveAlpha). Fixed: untargeted by GUID, usual zoom, 46 yd, GetAlpha, band/sight flips not counted |
| 13 | 2026-11-23 | /cine debug namescale (queue q5ca5) | sized for 8 yd: PASS one size (0.714) all walk at zoom 9.7, no errors | pairs unusable: this character (Coldridge) shows the game's full target plate when paused, not a name over the head; target plate at 1.2x (nameplateSelectedScale) |

