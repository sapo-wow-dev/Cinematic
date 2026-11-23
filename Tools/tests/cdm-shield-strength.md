# CDM shield strength: test ledger
Goal: a shield's tracked-buff icon (Power Word: Shield, Ice Barrier...) shows how much it can still absorb instead of the seconds left, colored green to red as it wears down (Discord #requests, Discipline, Forever, 2026-11-23).
Code: Dev/ShieldProbeTest.lua (probe + first build); planned UI/CooldownShields.lua (modeled on UI/CooldownStacks.lua)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | UnitGetTotalAbsorbs("player") with a shield up, out of a fight: plain? a real number (not 0)? | forever | SECRET even out of a fight, no shield up (Stormwind): no start size from it; Q5's description / aura points are the only ways | rule forever.absorbs.secret-out-of-combat (run 1) |
| Q2 | ... in a fight: secret? | forever | SECRET (3 of 3 changes) | run 2 |
| Q3 | Our FontString:SetText(secret absorb) draws the number | forever | YES: 5 of 5, drawn (44 down to 26 in the shot) | run 3 |
| Q4 | ColorCurve:Evaluate(secret absorb) from addon code: works or errors? (dump: SecretArguments=AllowedWhenUntainted) | forever | NO: errors every time | rule forever.curve.evaluate-refuses-secret (run 3) |
| Q5 | The shield's starting size readable: absorb read right after an out-of-fight cast, the aura's points (out of a fight), the spell description's number (in a fight too) | forever | description: YES, 44 for rank 1, plain in a fight; absorb read: no (secret); aura points: not reached (cast in a fight) | run 3 |
| Q6 | UNIT_ABSORB_AMOUNT_CHANGED fires for player: on the cast, on each hit, on the break; arg plain in fights | forever | YES: once on the cast, once per hit (3 in a short fight); unit arg plain | run 2 |
| Q7 | The shield's icon auraInstanceID on/off follows the shield in fights | forever | YES for buffs in general | memory forever-fight-aura-apis (stacktest 2026-11-14) |
| Q8 | The game's timer on that icon hidden by item:GetCooldownFrame():SetHideCountdownNumbers(true), no errors / blocked, in a fight too | forever | open (game code: CooldownViewer.lua:318 SetTimerShown does the same) | run 1 steps 1-3 |
| Q9 | UnitHealPredictionCalculator's GetDamageAbsorbs / GetMaximumDamageAbsorbs: what they hold (a cap by health? the shield's max?), secret in fights | forever | all SECRET, out of fights too (maxHealth too); no help | run 2 |
| Q11 | Is a shield in the game's Tracked Buffs catalog at all (can players track Power Word: Shield)? | forever | YES: Power Word: Shield 17 (cooldown 200047, known) and Fear Ward are in the catalog; just not added on the user's priest | run 3 |
| Q12 | Color without a curve: a StatusBar (0..start, SetValue(secret)) under or behind the number, its fill green-to-red cropped so the visible end shows how much is left, or a green copy of the number clipped by the fill edge over a red one (memory secret-health-clip) | forever | open: the user picks first | run 4 (the built feature) |
| Q10 | Two shields at once: one total (UnitGetTotalAbsorbs sums) | both | by design of the API; priest has one shield, not testable here | - |

## Plan tree
- Q1 plain + Q4 works: start size = the absorb at the out-of-fight cast (or Q5's description number for in-fight casts); color = curve red at 0 to green at start, Evaluate(secret) into SetTextColor. Build both.
- Q4 errors: color can't follow the amount. Fallbacks, both drawn in run 2 for the user to pick: one fixed color, or the green/red split by a clip frame on a StatusBar fill edge (memory secret-health-clip: StatusBar SetMinMaxValues(0, start) + SetValue(secret) drives the clip). Needs Q5 (a plain start) either way.
- Q3 no: the feature can't show the number in fights: (d) except out of fights; tell the player.
- Q8 errors / blocked: keep the game's timer and put our number above the icon instead.
- Q6 no event in fights: poll the absorb on a 0.2 s ticker while the shield's icon is lit (cheap).

## Build (2026-11-23)
UI/CooldownRing.lua + the Ring column (UI/CooldownGrid.lua LOOK.ring, Frames.lua base "off"), art Media/make_cdm_ring.py
(CdmRing8_*, CdmRing24_*, CdmDrainGrad). Any row (user: no spell filter). Styles Pips (8), Smooth (24), Liquid, Bar under.
Size = the cast rank's description number; segments = StatusBars stepped at (i-1)/n of it. Time left / charges: not
built (charges need the in-fight count probe; time left: GetAuraDuration in fights untested). Offline
Tools/offline/cdmring.lua ALL PASS (18). Game: /cine debug cdmring (Dev/CdmRingTest.lua).
Open for run 4: StatusBar takes the secret absorb (retail-tested only), RLE TGAs load, the ring look, Q8 n/a (timer kept).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | queue q6c3e shieldprobe | Q1: absorb read secret even out of a fight | everything else: ran on a level 6 mage (no shield), all 3 steps skipped. Not the test's fault; the prompt now says so when no shield is tracked. Tracked items read spell nil: now logs cooldownID + info too |
| 2 | 2026-11-23 | queue q0f7e shieldprobe | Q2 secret in fights, Q6 event fires per hit, Q9 calculator all secret | Q3/Q4/Q5: the test drew nothing without a shield icon (the test's fault: it made the label only on the icon). Run 3 draws on a stand-in square when no icon, takes the description from your own cast, reads the Tracked Buffs catalog (Q11) |
| scan 1-3 | 2026-11-23 | queues q9a36, q6334, qd1cc spellscan | a whole-game description scan can't work on Forever (rule forever.spell.description-needs-tooltip); the Tracked Buffs catalog per class reads fine (priest 35, shaman 28) | the shield / charges spell list comes from each class's catalog + the user's check, not from descriptions. Scan budget used: 3 runs, stopped there |
| ring 8 | 2026-11-23 | queue qe7be cdmring | preview labels under their icons (shot: Pips in class color, 44 / 26 / draining) | all steps proven; the full run before the commit |
| ring 7 | 2026-11-23 | queue qd9a2 cdmring | Style > Cooldown Manager page: 6 style/color combos from the page, On/Off grid, page on/off (off = pips), preview draws (shot: Bar, Green to red, 44/26/9) | the preview's labels sat off their icons (the preview scales its frames): pinned under each icon. Next: stylepage step only, hands off |
| ring 6 | 2026-11-23 | queue q3a05 cdmring | Liquid's water tint + surface line read full (44) and drop with the level (39); Amount column on the page; 36 sets, 0 errors | the user then had the water look undone (Liquid back to run 4's look, proven there); same open list as run 5 |
| ring 5 | 2026-11-23 | queue q92ff cdmring | fight: 70 updates, 58 sets for 6 hits, 0 errors; shot 36 left, 7 of 8 pips. All steps proven | open: groups/dungeons, a mage's shields, charges ring (probe), Time left (not built). Final `/cine debug cdmring full` before the commit |
| ring 4 | 2026-11-23 | queue q4119 cdmring | styles proven (liquid number fixed); the ring DOES count down in fights (shot: 34 after a hit, last pip dark) | 39 errors: the icon's width is secret in fights (rule forever.cdm.buff-icon-width-secret-in-fight); sized once out of a fight now. Run 5 (over budget: run 3's shots exposed the freeze the verdicts missed, then this second fight-only secret): fight step only |
| ring 3 | 2026-11-23 | queue qf498 cdmring | 9/9 PASS: size 44 via tooltip after /reload, 4 styles drawn (shots: pips, smooth, bar right; liquid hid the number), menu, ring hidden when the shield breaks | the shots showed the ring FROZE in the fight (44, 8 pips after a hit): verdicts couldn't see it. Likely the fight's secret spell ID erroring the row lookup inside pcall. Fixed: spell + size kept per icon, errors logged + counted, the fight verdict now needs updates > hits and 0 errors. Liquid's number on a frame above the bar |
| ring 2 | 2026-11-23 | queue q3714 cdmring | nothing: the user said PW:S was already tracked, the test never took it | real bug: after a /reload no description, so no size and no ring. Fix: size from a hidden tooltip when the description is empty (UI/CooldownRing.lua TooltipSize). Menu failed once (grid not shown, priest): a retry + state line added |
| ring 1 | 2026-11-23 | queue q414d cdmring | menu: the Ring column on Tracked Buffs Look (shot); a buff with no absorb (Lightning Shield) gets no ring, by design | everything else: run on the shaman, the test took Lightning Shield (named "Shield", no absorb). The test's fault: it now picks only icons with an absorb size and asks for the priest |
| 3 | 2026-11-23 | queue qb44f shieldprobe | Q3 number draws, Q4 curve refused, Q5 description 44, Q11 shield trackable | Q8 (hiding the game's timer on the icon): no shield icon tracked; goes into run 4 with the built feature (add Power Word: Shield to Tracked Buffs first). Run 3 of 3: one more is the build's confirm run |
