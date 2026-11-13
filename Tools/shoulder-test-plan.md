# Shoulder Cam plan

The Skyriding Cam got good by measuring first: find what the game does, simulate it, then build. This is the same approach for the Shoulder Cam, so each trip into the game answers as many questions as possible.

The Shoulder Cam stays a held setting, not a camera: it doesn't move the view and doesn't claim the camera lock. It stays dev-only until Phase 6.

## Where it stands

**Built:** on/off switch, offset, side, swap key, Show in row, pause while mounted and for our framing cameras, Frames follow you, DialogueUI hands-off.

**Open bugs and doubts:**

| # | What | Evidence | Fix in |
| --- | --- | --- | --- |
| 1 | The warning comes at every session, /reload included: the game clears the offset, so we must write it again. Stopping its event keeps it away (Run 2b, Forever). | Run 2, 2b | Phase 1: your decision below |
| 2 | "It keeps resetting even when off" wasn't reproduced on Forever in Run 2. Retail, where it was reported, is untested. | Run 2 | `watch` on retail if it comes back |
| 3 | Turned off in a fight, a protected frame stays moved for good: `PutBack` forgets it even if `Place` refused. | Sim: "Off in a fight" | Not on Forever: Run 1 shows neither frame protected out of a fight. Retail and Classic Era still to check |
| 4 | Frames follow you ignores model and mount size. The game scales the offset by them, so frames miss on anything but a standard model. | Sim: "Tall model", community reports | Phase 2 |
| 5 | At normal distance the offset barely shows. If the sum is right, 2 yards at 12 yards away is only 8% of the screen off the middle; a real third would take 4 yards. | Sim page, Try a shot | Phase 3 |
| 6 | Whether any of this exists on Classic Era and retail's frames is unknown. Forever has every setting. | Run 1, Forever | Run 1 |
| 7 | Frames follow you did nothing on Forever with a chained layout (cast bar on the PRD, the PRD on EssentialCooldownViewer). Fixed 2026-11-07: the first of ours in a chain moves, the rest ride along; plates stay. **Tested in a recording (left shoulder, Forever): the cast bar sits right under you at normal distances.** Zoomed right in (~1.5 yd) it went well past your body, to where your head-top is: frames now stop sliding further in than 3 yards | Run 1, recording | Done |
| 8 | ~~The sum assumed `cameraFov` is across your screen.~~ Fixed: it's across a 16:9 screen, the height kept (Run 3). | Run 3 | Done |
| 9 | The cast bar slid over the player frame: in Retail Inspired it sat on the PRD, and with empty Cooldown Manager rows (a low character) the stack sank it into the unit frames' band. Fixed 2026-11-07: the cast bar is 400 units up from the screen's bottom, as the unit frames are placed. **Tested: works**, then undone at the user's ask: the cast bar is back on the PRD in the stack; the Shoulder Cam layout (10) solves it instead | Screenshot, frames log | Replaced by 10 |
| 10 | A dedicated Shoulder Cam layout (dev only, Forever, Layouts.lua; mockup https://claude.ai/artifact/PPvLu5DMCUPEgBpNG2zEy6): the PRD is the one frame on the screen (UIParent BOTTOM 0,210), the cast bar and Cooldown Manager above it, swing timers hanging below it, player and target frames 200 out each side of it. Frames follow you moves the PRD and all of it rides along. The portraits are protected, so in fights the HUD holds still. Known limit: with Ranged bar on top on, the swing bars are pinned to screen spots and stay. Made with `/cine debug shoulder layout`. | Sim: "Shoulder Cam layout" passes | Game test |

## What we think the game does

From other addon authors and forum posts, none of it official or tested by us yet:

- The real offset is scaled by the size of your model, or of what you ride. It seems to be a share of the model's width.
- Each race and mount differs. Mounting moves you toward the middle; dismounting shifts the camera sideways.
- No event fires when that scale changes, so a correction applied at the wrong moment jerks the camera.
- Your chat bubble sits right over your character, which gives us a way to measure.
- Keep Character Centered blocks most of this (known since patch 9.0.1).
- The other experimental settings are `test_cameraDynamicPitch`, `test_cameraHeadMovementStrength`, `test_cameraTargetFocusEnemyEnable` and `test_cameraTargetFocusInteractEnable`, each with tuning values.

**Licensing:** two addons already correct for this with tables of race and mount sizes. We don't copy those tables: we measure our own.

## The tools

### Test commands (dev copy, ShoulderCamTest.lua)

Everything goes to the saved log under `shoulder:`. A `/reload` saves it.

| Command | What it does |
| --- | --- |
| `/cine debug shoulder` | State: switch, offset, pause reason, frames |
| `/cine debug shoulder scan` | Every camera setting and its default, which ones this client lacks, who you are |
| `/cine debug shoulder frames` | How the cast bar and PRD are anchored, and whether they're protected |
| `/cine debug shoulder watch` | Toggle, stays on over reloads. Logs every camera setting change and **who made it**, the warning popup, mounts and forms, and values at each login and logout |
| `/cine debug shoulder quiet` | Toggle, stays on over reloads; off takes a /reload. Tests keeping the warning away by stopping its event, as DynamicCam does |
| `/cine debug shoulder sweep offsets` | **Measures.** Says a line in /say, steps the offset 0 to 2, -1, -2, and reads your bubble at each step |
| `/cine debug shoulder sweep zoom` | The same at 5, 8, 12, 15, 20 and 28 yards, leaving out any past your max zoom. It puts your zoom back after |
| `/cine debug shoulder sweep ease` | Logs every 0.05 s through a big step: how fast the game eases |
| `/cine debug shoulder sweep next` | A bubble only lasts a few seconds. Says a new line and carries on |
| `/cine debug shoulder sweep stop` | Stops and puts everything back |
| `/cine debug shoulder try pitch` (`head`, `enemy`, `interact`) | Turns one experimental setting on for a look; again turns it off |
| `/cine debug shoulder try off` | Puts all of those back |
| `/cine debug shoulder on`, `off`, `left`, `right`, `offset 1.5`, `strength 120` | Sets it from chat, no page needed |

Sweeps say a real line in /say that people nearby can read, and need you outdoors, out of a fight and out of instances. Each step prints `real/worked-out`: 1.00 means the Frames follow you sum was right.

### The simulator (Tools/shoulder-sim)

```
python Tools/shoulder-sim/build_sim.py <out.html>
```

It plays a session through the real ShoulderCam.lua and ShoulderCamTest.lua: zooming, swapping, mounting, cameras, Edit Mode, a fight, a flight, dying. Each run checks that everything ends where it began. It stops with an error on any new failed check. To test your own saved settings:

```
python -I Tools/offline/run.py Tools/shoulder-sim/sim.lua yours out.json "<SavedVariables>/CinematicDev.lua"
```

**Rule, as with Skyriding:** before asking for a game test, run the sim on the defaults and on `yours`.

Numbers in `GAME` at the top of sim.lua are guesses. Each run below replaces one with a measurement.

## Test runs

Do a `/reload` first after any code change. Runs are grouped so one sitting covers a lot. Paste the first command of a run, do the steps, `/reload`, and say which runs you did.

### Run 1: what's here (each client, 2 minutes)

```
/run SlashCmdList.CINEMATIC("debug shoulder scan") SlashCmdList.CINEMATIC("debug shoulder frames") ReloadUI()
```

Answers: do these settings exist on Forever and Classic Era, are the frames protected, how are they anchored?

### Run 2: the login warning and the mystery writer (5 minutes)

```
/cine debug shoulder watch
```

1. `/cine debug shoulder on`, press Accept.
2. `/reload`. Did the warning come up?
3. Log out to the character screen and back in. Did it come up?
4. Quit the game fully and start it. Did it come up?
5. `/cine debug shoulder off`, play a minute, `/reload`.

Answers: does the value survive a reload, a relog and a restart, and what writes it while it's off?

### Run 2b: can the warning stay away? (3 minutes)

```
/cine debug shoulder quiet
```

First make sure DynamicCam and DialogueUI are off: both hide the warning themselves. Then `/cine debug shoulder watch`, `/cine debug shoulder on`, `/reload`, and check for the warning. Then a full relog. Then turn off `on`, `quiet` and `watch` the same way.

Answers: does stopping the event keep the warning away, is anything broken by it, and does it work on retail?

### Run 3: the real numbers (10 minutes, outdoors, somewhere quiet)

```
/cine debug shoulder sweep offsets
```

Then `sweep next` whenever it asks. Then `sweep zoom`, then `sweep ease`.

Answers: is a negative value really the left shoulder, is the shift straight with the offset, does it fall with distance as the sum says, and how fast does it ease?

### Run 4: sizes (15 minutes)

`sweep offsets` on each of: your main, a small race, a big race, a small mount, a big mount, a flying mount, a druid form if you have one. Keep `watch` on, so mounting and form changes are logged too.

Answers: how much each scales it, whether it's the same at every distance, and the moment the scale changes.

### Run 5: the look (15 minutes, just play)

`/cine debug shoulder on`, then walk, fight, ride, go indoors. With `try head`, `try pitch`, `try enemy` and `try interact`, one at a time.

Answers: where does it feel wrong, which experimental settings are worth keeping?

### Results

| Run | Client | Date | Result |
| --- | --- | --- | --- |
| 1 | Forever | 2026-11-06 | Every camera setting and ResetTestCvars are there. Offset 0, Keep Character Centered 1, max zoom factor 1. Cast bar on PRD, PRD on EssentialCooldownViewer, neither protected, so Frames follow you moves nothing. Screen 1835 x 768 |
| 1 | Retail | | |
| 1 | Classic Era | | |
| Notice | Forever | 2026-11-07 | Built and tested: our notice once, then no warning from Blizzard at the switch or a /reload. "Works" |
| 2b | Forever | 2026-11-07 | **No warning** with `quiet` on: not at the write, the /reload or the relog. Forever hears the event through GameEvent (`GameEvent.UnregisterInternalEvent` is there); UIParent wasn't listening at all, so the old way alone would have done nothing. Once stopped, the event stays stopped until a /reload. CameraReduceUnexpectedMovement was already 0 here, so it wasn't written |
| 2 | Forever | 2026-11-06 | The game clears the offset to 0 at every /reload, relog and restart; Keep Character Centered stays. So we write it each session and the warning comes each time (you saw it 3 of 3). It shows about a second after the write. Turned off, it restored both settings and nothing else wrote them for the 29 seconds logged. The reported "keeps resetting while off" didn't happen here |
| 3 | Forever | 2026-11-07 | Done, second try (the long line's bubble lasted the whole sweep). Dwarf, zoom 9: 0.5, 1, 1.5, 2 yards moved you 4.2%, 8.4%, 12.6%, 16.8% off the middle (shares of half the screen), and -1, -2 the same to the right: **negative is the left shoulder**, and it's a straight line, 1.01 of the fixed sum. Zoom 8, 12, 15: 0.98-1.01. **Zoom 5: only 0.44**, but the reading may have come while the zoom still moved; rerun with closer steps. The game eases over in about 0.3 s. First try: the ultrawide screen (2.39:1) made the old sum 0.74 too big; cameraFov is across a 16:9 screen, the height kept |
| 3b | Forever | 2026-11-07 | **No fade up close**: 1 yard moved you 4.9%, 6.2%, 9.4%, 12.6%, 15.3%, 19.3%, 26.3%, 41.0% at 15, 12, 8, 6, 5, 4, 3, 2 yards: 1.00-1.04 of the sum down to 4 yards, 1.06 at 3, 1.11 at 2 (as if the camera were ~0.17 yd nearer than its zoom reads: not worth a fix). Run 3's 0.44 at 5 yards was read mid-zoom. Up close you're near the top of the screen (bubble y 0.9 at 2 yards) |
| 4 | Forever | 2026-11-07 | Skyborne (sex 2: male), on foot, 15 yd: **0.86** of the Dwarf's (0.84-0.87 over 0.5 to 2 yards, both sides): a straight scale, so one number per model. Dwarf is 1.00. Still to do: other races, mounts, forms |
| 4 | Retail | 2026-11-13 | `mounts`, twice (Orc; read off the recording: the scenery's slide, a share of the width). On foot it's even: 1 yard slid 1.27% (zoom 10.35), 2 yards 1.62% (zoom 8.35), both ways. **Mounted, the two sides differ by 10 times**: -1 slides a few times the on-foot amount, +1 only a tenth of that, on every mount, the same with -2/+2 (the first run's "hillside" was this, not a wall). -1 against on foot: Amani War Bear 2.3, Arboreal Gulper 2.1, Black War Raptor 2.7, Gargantuan Grrloc 3.2-3.8, Ashes of Al'ar 4.6; Frost Wyrm (-2, zoom 8.35) 4.8. +1: 0.2-0.45. So mounted, one shoulder swings far out with the mount's size and the other hardly moves. No mount's number can be known without measuring it |
| Aim | Retail | 2026-11-13 | `aimclick` (Orc, offset 1.5, zoom 10.4, turn 1.5 s, read off the recording, 700 wide). Dummy at the far left (about -0.8 of the half-width): you slid 90 right (13% of the width), twice. Middle (cursor -0.02): no slide. Right (cursor 0.85, 0.80): you slid 95 left, twice. The dummy itself went from 0.86 to 0.46 off the middle: the turn halves its angle (yaw strength 0.5). So you slide about **-0.32 x the click's x** (both in shares of the half-width), easing in with the turn. The camera also tilts a little; you drop a few pixels. Your facing (GetPlayerFacing) reads fine outdoors and didn't change: you'd turned with the camera only. "Mouse over it" read false at the target change every time, so it can't tell a click from Tab. Only one zoom tried |
| Follow | Retail | 2026-11-13 | Frames follow the turn, first try with turning and moving (one click at x 0.22, then strafes and turns, read off the recording). Mostly within 3-5% of the width of you; misses of about 10% after the big turns. **UnitPosition's first number is north**: the strafes moved it, not the second (fixed; it had read strafes as walking toward or away). At the end you drifted 11% right with your facing and spot unchanged: the camera turned with the left mouse button, which nothing tells an addon. Now a left button held on the world over 0.3 s lets go of the guess |
| Follow 2 | Retail | 2026-11-13 | `follow` (zoom 8.1, ruler on the recording; you vs the PRD as shares of the half-width). Click far left: you +0.14, PRD +0.13. Far right: you -0.46, PRD -0.41. Strafe left then right: you -0.27 / -0.08, PRD -0.23 / -0.10. All close. **The right button undoes the game's turn**: while and after dragging with it you sat on your plain spot (-0.13), the guess at +0.03 to -0.21 the other way; the same in the fight (you -0.23, PRD -0.41). Now either button held lets go. **GetCursorDelta reads nothing while a button drags the camera** (it only follows the visible cursor), so a left drag can't be measured. Tab: no follow, as built. The turning step got no turn (your facing never changed) |
| Follow 3 | Retail | 2026-11-13 | `follow turning`, recorded. Turning with the keys tracks: clicked near the middle, you -0.11 / PRD -0.12; turned left about 25 degrees, you -0.31 / PRD -0.33; back, you -0.09 / PRD -0.09. Second run (not recorded): both mouse buttons let go as built; a 140-degree key turn put the guess at its cap with the dummy behind you, unchecked. Still to see: a strafe in a fight |
| Follow 4 | Retail | 2026-11-13 | `follow tab`: Tab gave no follow, hovering re-found it (dummy near the middle, so only about 2%); you and the PRD within 0.01 throughout. Tab is logged as "no click or key": the hooked Target functions don't run for the key. `follow behind`: with the dummy behind you, you sat at -0.17 (your spot -0.11): **the game hardly turns for a target that far round**. The guess sat at its cap (PRD -0.38) and flipped sides as the target crossed behind you. Turning back: within 0.01 again. Now it fades out from about 50 degrees to nothing at a quarter turn |
| Angles | Retail | 2026-11-13 | `angles` (zoom 9.2, follow off so the PRD marks the no-turn spot; held 3 s at each). Your slide, half-widths: 15 deg 0.04, 30 0.12, 45 0.16, 60 0.24, 75 0.29, 90 0.29, 110 0.30, 135 0.24, 160 0.17. **The game keeps turning well past 90 degrees** (the fade from 50 to 90 was wrong: "wild at 90"). The follow now reads this curve (aim.CURVE), 0 straight behind. One zoom only |
| Fight | Retail | 2026-11-13 | `follow fight` (in combat from the attack on; ruler, you vs PRD in half-widths). Clicked a dummy right of the middle: you -0.22 / PRD -0.23. Attacking: -0.21 / -0.19. Strafe left: -0.35 / -0.26 (the one miss, 0.09: likely the distance guess). A 13-yard strafe right: +0.10 / +0.10. Key turn left: -0.25 / -0.24; back: +0.09 / +0.05. **The game's turn toward the target acts the same in a fight**; the follow holds within about 0.04 there but for that strafe |
| 5 | | | |
| Forms | Forever | 2026-11-11 | `forms`, twice. Bear form 1.70 against the night elf's 0.82. The game alone has no sideways bump. Offset written at the model's change: 8-11 (of 945 wide) for 9 frames going in, 4-5 for 6 coming out. Written 1-2 frames earlier: 15 the other way. Pushed 35% past for 0.035 s going in: 7 for 2 frames, then level: built in (SWAP_PUSH). |
| Cams | Forever | 2026-11-11 | `cams`. An addon can run `ActionCam`. From off: `basic` = tilt 1; `on` = tilt 1, head movement 1, shoulder 1, interact focus 1; `full` = `on` + enemy focus 1; `headMove`/`heavyHeadMove`/`lowHeadMove` = head movement 1/2/0.5; `focusOn`, `focusOff`, `noHeadMove` nothing; `default` leaves unreadable text in five settings (never run it). 353 console settings have "cam" in the name; most have no help line. |
| Map: still | Forever | 2026-11-11 | `map still`, third try (see below). |

#### Map: still (night elf, standing, zoom 6.85, hair tracked off the recording)

Each setting on over a plain camera, then zoom in 3 yards and back. Where your hair sat: % of the screen's width off the middle, % of its height from the top.

| Setting | What it did |
| --- | --- |
| Plain | Middle (-0.3), 49.6 down. Zoom in 3 yards: 0.5 s to get 90% there, back out 0.35 s |
| `test_cameraOverShoulder` 2 | 13.9% left at 6.85 yards, 24.8% at 3.85: there in 0.1 s |
| + `CameraKeepCharacterCentered` 1 | **Cancels the offset entirely** (and the tilt, below) |
| + `CameraReduceUnexpectedMovement` 1 | **Cancels the offset entirely** |
| `test_cameraDynamicPitch` 1 | You sit 1.7% lower at 6.85 yards, 6.6% higher at 3.85: it grows as you zoom in; 0.5 s |
| + `BaseFovPad` 0.2 (default 0.4) | 8.8% lower at 6.85 (3.3% higher at 3.85) |
| + `BaseFovPad` 0.7 | 6.6% higher at 6.85, the same zoomed in |
| + `BaseFovPadDownScale` 1, `BaseFovPadFlying` 0.2, `SmartPivotCutoffDist` 30 | As the tilt alone (standing, on the ground, this camera angle) |
| `cameraDistanceRateMult` 3 | Zoom 3 times as fast (0.17 s in, 0.13 s out) |
| `cameraZoomSpeed` 5 / 50 (yours 20) | No real change over 3 yards (0.58 / 0.48 s in) |
| `cameraFov` 60 | You look 1.6 times as big |
| Head movement 2 and its standing strength, damp rate, range scale, dead zone | Nothing standing still |
| Bobbing, custom view smoothing, ground smooth speed, yaw and pitch smooth speed and min/max, pivot off and its DX/DY, smooth off, smooth pitch/yaw off, follow styles 1/2/4, smooth time, tracking style 1, target smooth speed, terrain tilt, Z smooth 0/2, action combat camera, follow on stick, max zoom factor | Nothing standing still: for the walking and target runs |

#### Map: talk (a vendor 9.1% right of the middle, zoom 6.66, its target ring tracked off the recording)

`map talk`, 2026-11-11, first try. One right-click per trial; the window closed for you after 2.5 s.

| Setting | What it did |
| --- | --- |
| Focus off | No turn |
| `test_cameraTargetFocusInteractEnable` 1 | The NPC brought to the middle (9.1% right to 1.3% left) and 7.7% up the screen. Half way in 0.07 s, 90% in 0.17 s; back in 0.23 s once the window closes |
| `...InteractStrengthYaw` 0.3 / 2 (default 1) | 0.3: 31% of the turn (straight share). 2: the same as 1 (capped) |
| `...InteractStrengthPitch` 0 / 2 (default 0.75) | 0: no tilt. 2: 10.1% up, what 1 would give (capped) |
| `cameraTargetSmoothSpeed` 10 / 400, `cameraYawSmoothSpeed` 20, `cameraPitchSmoothSpeed` 5, `cameraSmooth` 0, `cameraSmoothStyle` 4 | **No change to the turn or its speed** |
| With `test_cameraOverShoulder` 2 | The NPC ends in the same place (1.7% left): the focus wins over the offset's sideways shift |

So there's no speed setting: the turn's always about 0.2 s. The strengths are straight shares, so a slower turn would be ours to make by stepping the strength up from 0 (not yet tried: whether a strength changed mid-talk moves the view at once). The NPC's nameplate can't be measured on Forever either (GetCenter refused).

#### Map: ramp (the same vendor, 2026-11-11)

`map ramp`: the strengths changed while the window's open. **The turn follows them**:

| Trial | What it did |
| --- | --- |
| Focus on | The usual snap, 0.2 s |
| Strengths 0, full at 1.5 s | Still till 1.5 s, then the usual snap |
| 0 to full over 2 s (eased) | **A smooth glide** over the 2 s, about 0.1-0.2 s behind the strength written, then holds |
| The same, turn only | The same glide sideways, no tilt (0.6% of height) |
| Focus switched on 1.5 s in | Works mid-talk: the snap at 1.5 s |

So a slow turn to whoever you talk to is ours to make: focus on with strength 0, then step the strengths up per frame. The way back as the window closes is still the game's 0.2 s snap (not yet tried: easing it back down before the window closes, or whether the focus holds a moment after).

#### Map: back (the same vendor, 2026-11-12, NPC 5.5% right of the middle)

`map back`: slowing the way back as the window closes (the game's 0.2 s snap, "really fast").

| Trial | The way back |
| --- | --- |
| As built (twice) | The snap: 90% back in 0.2 s |
| Camera follow swinging you round behind (ns.CenterCamera), focus kept | **Nothing moved**: the same snap (camera follow doesn't turn a standing camera) |
| The same, focus eased off as it swings | A glide back over 1.5 s, all of it the strength coming down; the follow added nothing |
| Strengths eased to 0 before the close | **A smooth glide back over 1.5 s**, nothing left at the close |

Your facing: the first click turned you from 23.9 to 49.1 degrees to face the NPC; later clicks, already facing them, none. So the only slow way back is the strengths coming down before the window closes: possible only if we know the close is coming.

#### Zoom curve and cat (Menethil, 2026-11-12, Night Elf, offset held at 1.18)

`zoomcurve`: the game's zoom against a written offset, plus cat form. "Zooming feels staircase like: it goes right really fast, then stops."

| What | On screen (the hair, % of width off the middle) |
| --- | --- |
| Zoom in 2 (5.38 to 3.38), offset held | -10.2 to -16.4: a smooth glide, 90% in 0.45 s, size 90% in 0.55 s |
| Zoom out 2 | 90% in 0.3-0.35 s |
| Both, in camera distance | about an ease of 0.19 s (63% in 0.19 s) |
| Zoom in 5 (to 0) | first person: the hair's gone |
| Offset +1 yard | -11.1 to -20.5: 70% in 0.05 s, 90% in 0.1 s |
| Cat form, the elf's offset | the cat on -20.3%, the elf on -10.8%: a factor of 0.82 x 20.3 / 10.8 = 1.55 |

GetCameraZoom gives the zoom's end at once (every frame read in the run). So the offset for the end was written at once and the game put it in within 0.1 s, while the camera took 0.4-0.5 s: the sideways jump, then the stop. Built: the offset follows a distance eased toward the zoom's end by 0.15 s (the glide's 0.19 less the offset's 0.04), and cat form has FORM_SCALES 1.55 (tried in game that day: "feels smooth"). The cat sits low and right in front of the camera with the shift's smoke over it for about 2 s; that's the game's.

#### Walls (Menethil Keep courtyard, 2026-11-12, a wall corner by a tree, zoom 15, offset 3.30)

`walls`: two 20 s walks along the wall and past the tree. GetCameraZoom read 15.0 every frame of both: **the game's pull-ins near walls can't be seen from code**. `cameraIndirectVisibility` was already 1 (its default) in the first walk, so the second only raised `cameraIndirectOffset` 6 to 10: no change on screen. In both, the camera pulled in near the wall and the tree while the offset stayed at 3.3 yards (for 15 yards away), so you went far off to the side, behind the tree trunk or out of the picture, and came back as it let go. The console list (281 camera settings) has nothing for collision. So nothing the game gives us sees a wall or stops the pull-in.

Then (that evening) the offset capped at 1.5 yards (OFFSET_SAFE): "felt a little better, still not perfect smooth". A second `walls` run, the same walk with no offset at all and then as built (capped): **the two looked the same**. The game alone hugged the wall, pulled in and out and hid you behind the trunk just as often. So what's left near walls is the game's own camera; the cap only stops the offset making it worse. The cost: past about 6 yards the spot isn't held (12.5% instead of 20% at 12 yards; the sim's spot and bear checks fail by that).

#### Map: walk (Stormwind streets, 2026-11-12, zoom 15, offset 1.5, your follow style 0)

`map walk`: 12 trials of walk, turn left, stop, one game setting each (follow styles 0/1/2/4, terrain tilt, tilt, head movement and two of its knobs, bobbing). All the settings exist on Forever. Read off the recording as the whole picture's frame-to-frame jitter (its move less its 0.3 s average) while walking: trials 1, 2 and 12 had the same settings and came out 0.09 / 0.27 / 0.55 sideways and 0.20 / 0.24 / 2.38 up and down, as far apart as any two settings. So the walks themselves (mouse turns, ground, a turn left or none: in 6, 11 and 12 your facing never changed) swamped whatever the settings did: **no setting stood out**. A clean answer would need the same walk every time, which only a script could do (an addon can't walk you).

Second walk run (flat open ground, zoom 9.6, keyboard only: W, then the turn key; A is strafe for the user, so turns were the arrow key, held for different times: 10 to 160 degrees). Jitter, sideways / up and down: as built 1.71 / 0.38, 2.62 / 0.43, 2.06 / 0.62 (the spread of the same settings); follow style 2 2.34 / 0.61, style 4 2.62 / 0.54, terrain tilt 3.05 / 0.57, tilt 2.96 / 0.41, head movement 1 2.43 / 0.58, bobbing 1.20 / 0.57. Up and down all inside the spread; sideways follows how much each walk turned (tilt turned most, bobbing least). **None of the game's walking settings steadies the view**: what shake there is isn't theirs to fix.

#### Map: enemy (Forever, a Young Goretusk, 2026-11-12, zoom 9.5, offset 1.5)

`map enemy`: target, hold 5.5 s, clear, per trial. The game's own strengths on Forever: turn 0.5, tilt 0.4. Read off the recording by the target's health bar: with the focus on, the boar slid 1-3% of the screen toward the middle within ~0.5 s of the target (7.1 to 6.1, 8.4 to 6.3 at strength 0.3, 3.6 to 1.1 eased in); with it off, nothing pulled. But the boar started only 3-11% off the middle and wandered (in three trials it walked across the screen while targeted), so how far and how fast is unread. Next: a target dummy on retail, standing still, well off to one side.

Retail at a Training Dummy (Orc, zoom 13.6, the same strengths 0.5 / 0.4): your facing never moved, but the dummy stood almost straight ahead, ~1% off the middle, and stayed there in every trial, focus off too: nothing to turn. Next: the dummy well off to one side (the camera dragged round with the left mouse button before starting).

Retail again, the dummy ~18% right of the middle (your facing never moved), read as the whole picture's slide after each target and clear: focus off, focus on (0.5 / 0.4), strength 0.3, tilt 0 and focus on again: **no turn at all**. Eased in over 1.5 s: a smooth turn of 3.8% of the width in 0.7 s; eased in then back before the clear: the same turn, then a smooth glide back. After a clear the camera **stayed turned** (no snap, unlike the interact focus) till the strengths came down. So out of combat the enemy focus only moves while its strengths are changing (untested: in combat, where it may act on its own).

What the first two tries taught: a turn or tilt speed setting written low is put back by Core.lua's speed watch unless held with `ns.SetHeldSpeed`; `SetView` blends over about a second; the standing-still and chat cameras start mid-run unless the run holds the view (`ns.RegisterCamera`); the recording's clock ran 1.0 s ahead of the log; block matching fails on dark grass, tracking the hair's colour works.

## Build phases

Each phase ends with the sim passing, including its new checks, then one game test.

### Phase 1: solid ground (after Runs 1 and 2)

- Settle the login warning: **built 2026-11-07.** Our notice once (Accept or Cancel), then the game's warning kept quiet while it's on. You chose this over one warning per session.
- Step aside when DynamicCam is on.
- Fix the frames left moved after a fight: keep them and put them back when the fight ends.
- Frames follow you on chained layouts: move the first frame in the chain that's ours to move, and let what's anchored to it ride along, never both.
- Correct the file header's claim about logout.
- Solve the "off but still on" report with `watch`.
- Sim: fix the `KNOWN` failures in build_sim.py.

### Phase 2: size correction (after Runs 3 and 4)

**Started 2026-11-07:** a size factor per race and sex (Dwarf 1.00, Skyborne 0.86 built in). Each `sweep offsets` on foot saves yours; Spot on screen and Frames follow you both use it. `/cine debug shoulder` shows it. Mounts and forms still to measure.

- Our own measured factors, by race, and by mount size if a pattern holds.
- A **calibrate** button: say a line, read the bubble, save the factor for what you're on now. This covers every mount without a table.
- Writes the corrected offset, so the look stays the same as you mount and dismount.
- Frames follow you uses the same factor.
- Retire "Not while mounted" as the only answer, or keep it as a choice.
- Sim: real factors in `GAME`; a new check that framing holds through a mount.

### Phase 3: framing that holds (after Run 3)

**Built 2026-11-07:** Spot on screen replaces Offset (you chose replace). Default 20% of the way to the edge, 5-40%. The offset follows your zoom every frame (written when it changes by 0.02 yd or more, up to 15 yd), and eases to the middle closer than 4 yards. Sim check: your spot holds as you zoom. Untested in game.

- **Hold your spot on screen:** you pick a spot, say 20% off the middle, and the offset grows with distance so it stays there as you zoom. Probably the biggest improvement to the look.
- **Ease to the middle up close,** so first person and tight shots don't throw you off.
- Limits for how far the offset can go. The slider stops at 2 today; Try a shot shows why that's too low.
- Sim: a check that your spot holds within 2% through a zoom.

### Phase 4: situations

- Per-situation offsets: in a fight, indoors, swimming, in a group, each with its own value or off. These can ride on the Show in row and CQL rather than new settings.
- Smooth side changes for a swap, if the game's own ease isn't enough.
- Auto side: swap toward open space or toward your target. Needs the look test first.
- Sim: a session for each.

### Phase 5: the rest of the action camera (after Run 5)

Only what passes the look test: head movement, dynamic pitch, target focus. Each one writes a test_ setting, so each is held and restored, an allowed exception to not mirroring game settings. Target focus turns the camera, so check it against the camera lock first.

### Phase 6: joining the rest of Cinematic

- A scene step in camera scripts: set the shoulder for a shot, put it back after.
- Replace the pause with real handovers: quest cam and Chat Cam choose a side based on who you're talking to.
- Frames follow you for more frames, if wanted.
- Release: Cinematic.toc, What's new, docs page, translations at release.

## Decisions for you

- Where new controls go on the page (asked per control as each phase starts).
- Is one warning per login acceptable, if that's what Run 2 shows?
- Is the sweep's line in /say OK, or should it use a party or a private way? A private way may not make a bubble.
- Does the Shoulder Cam go public, and on which clients? That waits on Runs 1 and 2.

## What DynamicCam does (read 2026-11-06, v2.21.6, MIT license)

| Topic | What it does | For us |
| --- | --- | --- |
| The warning | Never shows it: `GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")`, or `UIParent:UnregisterEvent(...)` before WoW 12.1. DialogueUI does the same | The likely answer to bug 1. `quiet` tests it |
| Blocking settings | Turns off `CameraKeepCharacterCentered` **and** `CameraReduceUnexpectedMovement` (needed since 11.0.2), and prints that it did | We missed the second. Fixed: held and restored like the first |
| Timing | Waits 0.1 s after startup: "the camera doesn't like changing cvars on startup" | We write at PLAYER_ENTERING_WORLD. Delay it if a login looks wrong |
| While zooming | Doesn't write the offset mid-zoom | Check in Run 5 |
| Range | Offset -15 to 15 | Our 2 is far too low: Phase 3 |
| Zoom | The offset can follow a curve you draw against distance, with easing | Same aim as Hold your spot; ours is one spot instead of a curve |
| Situations | Eases the offset per situation, with its own timing | Phase 4 |
| Model and mount size | **Not in DynamicCam.** It's a separate addon, CameraOverShoulder Fix, which DynamicCam calls if present (`cosFix`) | Still ours to measure: Phase 2 |
| Screen frames | Doesn't move them | Frames follow you is ours alone |

If DynamicCam is on, it owns the offset and writes it constantly, so we must step aside. That moves up from Phase 6 to Phase 1.

## Sources

- [CameraOverShoulder Fix](https://github.com/Bitwise1057/CameraOverShoulderFix) and [its CurseForge page](https://www.curseforge.com/wow/addons/cameraovershoulder-fix-dynamiccam)
- [SteadyCam](https://www.curseforge.com/wow/addons/steadycam)
- [Behaviour of test_cameraOverShoulder (forum)](https://eu.forums.blizzard.com/en/wow/t/behaviour-of-test-cameraovershoulder-console-variable/50630)
- [CVar ActionCam (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/CVar_ActionCam)
