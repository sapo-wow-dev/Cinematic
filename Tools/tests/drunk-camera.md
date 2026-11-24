# Drunk camera snaps: test ledger
ON HOLD (2026-11-23, user): run 3 (q9bfe) taken off the queue before it ran. Next: queue `drunkcam` again (sober first), read Q8's timed setting changes against the marks.
Goal: being drunk never makes Cinematic's camera jump or swing around (player report 2026-11-23, Forever, clip: one-frame snaps at 0:14.9 and 0:15.7 while running on a mount in Tanaris).
Code: Camera/Camera.lua (IsTurning 1744, UpdateTurnFollow 3678, axes 37-49, MoveAxis 1773), Core.lua held speeds (3570-3660), Dev/DrunkCamTest.lua, Tools/offline/drunkcam.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does being drunk change GetPlayerFacing on its own (weaving) while auto-running? | forever | Slow drift 3-25 deg/s with no keys, mostly under IsTurning's 20 deg/s; no sober run to compare yet. The big jumps (12 deg in a frame, 1261 deg/s) came at a step's start, likely you turning | run 2 (q4e47) steps 3-5 |
| Q2 | If so, how: small steady wobble, or jumps of several degrees in one frame? | forever | small steady drift (see Q1) | run 2 |
| Q3 | Does the turn hold (runSwingBehind) drive the yaw hard and toggle cameraSmoothStyle? | forever | NO: yaw push 0 and no cameraSmoothStyle change in every step | run 2 |
| Q4 | Jumps with turn hold off / CineMode off? | forever | You saw 2 jumps (CineMode on), 3 (turn hold off), 0 (CineMode off; the auto-run camera's sway still ran), 0 holding forward | run 2 marks |
| Q5 | Holding forward (no travel camera)? | forever | no jumps, no view calls | run 2 step 6 |
| Q6 | Another caller sends MoveView? | forever | NO: every call was ours (the test called them OTHER: the dev copy's folder is CinematicDev; fixed) | run 2 stacks |
| Q7 | Does it happen sober too (is drunk even needed)? | forever | open | run 3 steps 1-2 |
| Q8 | What changes right before a jump? Run 2 saw camera settings written over and over (untimed): cameraZoomSpeed x1498 (20), cameraPitchMoveSpeed x112 (90), cameraYawMoveSpeed x10 (180), test_cameraOverShoulder x318 (1.43-1.46). A move started at a crawl speed (sway sets the speed to 1) speeds up 90-180x if the speed goes back mid-move. | forever | open | run 3: every change timed with its file:line; each mark lists the changes in the 1.5 s before it |
| Q9 | What does Forever say when you get drunk? (run 2 caught no drunk line) | forever | open | run 3 drink step logs the game's strings and the last system/emote lines |

Nothing about drunk in the engine rules, logs or memory (known.py drunk, 2026-11-23).

## Plan tree (step 3)
- Q8 shows a speed / zoom setting going back up right before marks -> our held-speed churn (Core.lua HoldSpeed/ReleaseSpeed, the sway's AxisRate) lets a crawl move run at full speed. Fix: hold the speed for the whole move, or stop the axis before putting the speed back. Then a confirm run (sober is enough if Q7 says yes).
- Q8 shows test_cameraOverShoulder flipping near marks -> Shoulder Cam offset writes while the auto-run camera runs; fix there.
- Q8 shows nothing near marks -> a per-frame facing/yaw cause after all: widen with the yaw axis state per frame (already in the mark dump).
- Q7 no (sober never jumps) -> drunk is involved after all: compare drunk vs sober writes and facing.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | qa610 (/cine debug drunkcam) | nothing | stopped by you at step 3 (steps 1-2 skipped; Stormwind, not drunk): no recording. Doesn't count toward the budget |
| 2 | 2026-11-23 | q4e47 (/cine debug drunkcam) | Q2-Q6 | Q1 half (already drunk: no sober run); Q8 the setting writes weren't timed or tied to who wrote them (the test only had the console's counts); the drunk line wasn't caught |
