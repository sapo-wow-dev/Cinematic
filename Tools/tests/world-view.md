# World between the bars: test ledger
Goal: with the letterbox up, the world draws only between the bars (a wide picture, nothing hidden under them)
Code: Atmosphere/Letterbox.lua (PlaceWorld, letterboxWorld), Style/LetterboxStyle.lua (the switch), Effects.lua (NotchGap), Dev/WorldViewTest.lua; offline Tools/offline/letterboxworld.lua + worldview.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Can an addon re-anchor WorldFrame out of fights? | forever | YES (protected, but allowed out of fights) | run 1 step 2, rule forever.worldframe.move-out-of-fights |
| Q2 | Is the picture a wider view or a stretched one? | forever | wider view, not stretched; strips black without bars | run 1 shots 081822, 081828 |
| Q3 | Does the game put WorldFrame back by itself? | forever | no (3 s) | run 1 step 2 |
| Q4 | Cost of moving it every frame while the bars ease in | forever | 0.009 ms a call; frames 10.38 vs 10.08 ms | run 1 step 3 |
| Q5 | Put back with SetAllPoints() | forever | yes | run 1 step 4 |
| Q6 | Allowed in PLAYER_REGEN_DISABLED (lockdown yet?) | forever | yes, lockdown false there | run 1 step 5 |
| Q7 | Allowed inside a fight, or blocked (WorldFrame protected?) | forever | BLOCKED (IsProtected true, ADDON_ACTION_BLOCKED, no move) | run 1 steps 1, 6 |
| Q8 | Anything blocked or tainted after the fight | forever | nothing; moves again after | run 1 step 7 |
| Q10 | Same on retail | retail | open (likely the same: same CinematicFrame code) | run 2 |
| Q9 | Cutscene while squeezed | both | from code: CinematicFrame sets its own points on CINEMATIC_START and SetAllPoints on hide; the feature must step aside then, no probe | CinematicFrame.lua |

## Plan tree
Q1 no -> (d) can't; reply says so. Q1 yes + Q7 no + Q6 yes -> build: squeeze out of fights, put back in PLAYER_REGEN_DISABLED (bars that stay in fights stay plain overlays). Q6 no too -> the bars that stay in fights can't use it: switch only when "off in fights" is on. Q7 yes -> works everywhere. Q4 slow -> snap once the bars are in instead of every frame. Q2 stretched -> (f), not worth it. Run 2 = the built feature (then also: mouse picking on the squeezed world, Chat Cam's double bars, screen size change).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-24 | /cine debug worldview (qbd76) | Q1-Q8: out of fights yes, wider view, free; put back in PLAYER_REGEN_DISABLED works; in fights blocked | Q10 retail (not asked yet); built feature not tested (none built) |

Picked branch: Q1 yes + Q6 yes + Q7 no -> squeeze out of fights, put back in PLAYER_REGEN_DISABLED, again after the fight; bars that stay in fights stay plain overlays there.
| 2 | 2026-11-24 | /cine debug worldview (q35ae: steps 8-9, the built switch) | 9/9 PASS, 0 blocked: between the letterbox bars, switch off/on, bars out, whole screen in a fight, back after | retail (Q10); Chat Cam bubble reads with the world squeezed |

Design change 2026-11-24 (the user): a fight keeps the world between the bars and holds the bars (no leaving till it ends) instead of putting the world back as it starts. Step 9 reworked, unproven.
| 3 | 2026-11-24 | /cine debug worldview (qa8a3: step 9 reworked) | 4/4 PASS, 0 blocked: world between the bars through the fight, bars held even asked out (key, off-in-combat default), out and whole after | retail (Q10); full run before the commit |
| 4 | 2026-11-24 | /cine debug worldview (q644e: step 8, eased switch) | 7/7 PASS: switch off eased over 170 frames (biggest step 19.3 of 192), on over 163 (20.8), 0 blocked | retail (Q10); full run before the commit |

Top and bottom bars apart 2026-11-24 (the user): Letterbox Style's Top bar / link / Bottom bar (letterboxSizeBottom, letterboxLinked, linked by default). New step 9 apart (fight is step 10 now). Run qafed hung: CineMode's bars still going out as the step began, the key flipped them out; the step now waits them out first and every wait gives up.
| 5 | 2026-11-24 | /cine debug worldview (q6656: step 9 apart) | 11/11 PASS, 0 blocked: 3%/9% each bar its own, the world in by each, notch gap same; page's Top bar, link, Bottom bar clear; link on: even, off: bottom keeps its height | retail (Q10); full run before the commit |
