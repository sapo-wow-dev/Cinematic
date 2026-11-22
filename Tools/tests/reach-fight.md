# Reachable in fights: test ledger
Goal: no "bad self" or "'for' limit" errors in fights (issue #7), without skipping any frame Cinematic should still fade, and at no real CPU cost.
Code: Checks.lua (ns.Reachable, Check.Reachable), Core.lua (ns.NumPoints), Frames.lua (IsForbidden helper), FadeDetached.lua, Support/EllesmereUI.lua; test Dev/ReachFightTest.lua (`/cine debug reachfight`), offline Tools/offline/fightpoints.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Out of a fight, does any object that isn't forbidden refuse GetParent? (ns.Reachable only probes in fights) | forever | NO: 0 refuse out of a fight, with Cinematic alone and with the EllesmereUI suite (126585 objects) | runs 1-3 |
| Q2 | In a fight, which objects refuse, and are any of them frames Cinematic fades (ns.managed) or nameplates? (those would now be skipped) | forever | 6710 of 129411 refuse in a fight with EllesmereUI (0 with Cinematic alone); none is a frame Cinematic fades or a nameplate part: nothing skipped | run 3 |
| Q3 | Does ns.Reachable agree with a fresh probe for every object in the fight (the per-fight memory never stale)? | forever | YES: 0 differ, with 6710 refusing | run 3 |
| Q4 | Cost: ns.Reachable per call (first probe, remembered), and over every nameplate and its UnitFrame | forever | old IsForbidden-only guard 0.36-0.50 us; ns.Reachable 0.73-0.86 us out of a fight, 1.73 us cold and 0.81 us remembered in one: about +0.35 us a call; plate parts 0.001-0.003 ms a pass. Cheap enough | runs 1-2 |
| Q5 | Does CanBeAccessedInContext / HasAnyAccessRestrictions predict the refusal? (then a real check can replace the probe: Tools/pcall-plan.md) | forever | CanBeAccessedInContext YES: false on exactly the 6710, no miss, no false alarm, never secret. HasAnyAccessRestrictions NO (true on 8280 out of a fight, none refusing; 0 in it). Rule forever.frame.not-forbidden-still-refuses tested | run 3 |
| Q6 | How many objects give a secret GetNumPoints in a fight, and does ns.NumPoints give 0 for every one? | forever | rare without other addons (2-3 in a fight, 1 out); with EllesmereUI 594 out of a fight and 1089 after: out of combat too, often. ns.NumPoints 0 for every one | runs 1-3 |
| Q7 | After the fight: do refusals go away (the memory is wiped, ns.Reachable stops probing)? | forever | YES: 0 refuse after the fight (runs 2-3) | runs 2-3 |
| Q8 | Do EllesmereUI's chat parts refuse here too (issue #7's setup)? | forever | YES: issue #7's setup reproduced: 6710 refusals in the fight, and 0 errors, 0 blocked with the fix in | run 3 |

Known going in: rule forever.frame.not-forbidden-still-refuses and forever.frame.numpoints-secret-in-fight are inferred from players' logs only, never seen here. EnumerateFrames works on Forever (forever.targetframe.aura-container-place-secret). CanBeAccessedInContext exists on every region (apidocs, SecretReturnsForAspect), never called.

## Plan tree
- Q1 yes (refusals out of fights) -> ns.Reachable must probe always; then need: Q4's cost out of a fight (step 1 times a forced probe too).
- Q2 managed frames or plates refuse -> they'd stay up in a fight; need: which (names logged), and whether a refusing frame still takes SetAlpha (not probed: a write could taint; only if Q2 says so, next run).
- Q3 disagree -> drop the per-fight memory or wipe it more often; step 2 logs which objects changed.
- Q4 remembered call over ~1 us, or plates over 0.05 ms per pass -> keep the memory by frame only for walkers, plain IsForbidden for plates.
- Q5 matches every refusal and no false alarm -> swap the probe for the check (no pcall); partial -> keep the probe, log the rule.
- Q6 any secret count ns.NumPoints doesn't zero -> bug in ns.NumPoints.
- Q7 refusals stay after the fight -> wipe at PLAYER_REGEN_ENABLED is wrong; probe for a while after.
All answered in run 1 (one fight).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | `/cine debug reachfight` | Q1, Q2, Q3, Q6 with Cinematic alone; Q4 mostly; Q5 no false alarms | Q2/Q5/Q8: only CinematicDev was loaded and the refusals come with other addons (issue #7 had the EllesmereUI suite), the test didn't set that up. Q7: the log was saved 2 s after the fight, before step 3's read (a /reload, likely: the box said nothing while it slept). Fixed: a setup step turns EllesmereUI on (put back after), step 4 says "reading, don't reload", the old guard is timed, secret-count frames are named |
| 2 | 2026-11-22 | `/cine debug reachfight` | Q4 (old guard timed), Q6 (named; one out of a fight), Q7 | Q2/Q5/Q8 still with Cinematic alone: EllesmereUI never loaded. The test's fault: the setup used EnableAddOn(name, UnitName("player")), which a rule tested the same day (forever.addons.enable-no-character) says does nothing on Forever; known.py wasn't run for EnableAddOn before building it, and the test didn't check the addon loaded, so it went on unseen. Fixed: EnableAddOn(name) + SaveAddOns (put back the same way), and step 2 FAILs with the game's reason when EllesmereUIChat isn't loaded |
| 3 | 2026-11-22 | `/cine debug reachfight` | all: EllesmereUI loaded; Q1-Q8 answered; 7 pass, 0 fail, 0 errors, 0 blocked | none. Runs used: 3 (run 2 wasted by the test's setup, see its line) |

| 4 | 2026-11-22 | `/cine debug reachfight 1 2 3` | the swap confirmed: ns.Reachable asked CanBeAccessedInContext in the fight, matched a fresh probe on all 129983 objects (6710 refusing again, none ours), cold call 1.46 us (was 1.80 with the probe), remembered 0.88 us; 6 pass, 0 fail, 0 errors, 0 blocked | none. Done: 4 runs (3 + this confirm of new code) |

Run 4 is a confirm run, not a broken plan: run 3 closed every question, and the plan tree's Q5 branch said "matches every refusal -> swap the probe for the check", which is new code.

## Outcome
The fix holds in issue #7's setup: thousands of objects refuse in a fight, none of them ours to fade, no errors. Then (Tools/pcall-plan.md) ns.Reachable asks CanBeAccessedInContext() in fights instead of the pcall probe (exact on 129411 objects), the probe kept for clients without it; offline in Tools/offline/fightpoints.lua, confirm in run 4.
