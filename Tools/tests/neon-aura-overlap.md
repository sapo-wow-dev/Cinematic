# Neon Coast target buffs over the name plate: test ledger
Goal: with a Style theme's name plate on the target (and focus) frame, the game's buff row on top never covers it (Discord report 2026-11-21, Neon Coast).
Code: Style/UnitAuraLift.lua (the fix), Style/UnitStyle.lua (calls it after FramePlate), Dev/AuraPlateTest.lua (confirm run), Tools/offline/auralift.lua + auraplate.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does the target frame have buffsOnTop, and where do its auras live (Forever container / retail pools)? | forever | PART: GetAuraContainer (one container), frame.buffsOnTop false, UpdateAuras exists, no UpdateAuraPositions; icons' places: run 2. Edit Mode Buffs on Top on Forever: run 2 | run 1 context line |
| Q6 | Which client is the player on? Forever had buffs under the frame, the report has them on top | both | open: asked in the reply (/cine log); run 2 says whether Forever can put them on top | run 2 step 3 |
| Q2 | Aura row's bottom vs our plate's top (all its regions: edges, corners), in px | both | open | run 1 step 4 |
| Q3 | The game's own gap: aura row bottom vs the frame art top, no theme | both | open | run 1 step 3 |
| Q4 | Fix A: moving the aura row up (AdjustPointsOffset) holds out of fights, no BLOCKED? | both | open | run 1 step 5 |
| Q5 | Fix A in a fight: rects secret? move blocked? does the game re-lay the row on a new aura? | both | open | run 1 step 6 |

## Plan tree (after run 3)
- Row place unreadable on Forever, so no measuring it. Fix A': hook the container's SetPoint and AdjustPointsOffset it up by our plate's overhang (rule forever.region.adjustpointsoffset-secret), the overhang from readable parts: plate top minus the game's own name strip top (name top 233.6 px no theme vs plate top 239.4 px Neon, run 3). Fix B: keep the plate's top at the game's strip top when buffs are on top. Next run = confirm with screenshots, waiting for Edit Mode closed and the target still there.

## Plan tree (before run 1)
- Q2 overlap <= 0: the plate isn't the cause; look at the corner art / shadow lines the log lists, or another frame (focus, boss). Q2 > 0: fix.
- Fix A (move the game's row up by overlap + Q3's gap): if Q4 holds and Q5 isn't blocked, hook the game's aura layout and re-apply after it (needs: which call lays it out, logged per client in step 1). If Q5 blocked or secret in fights: fix B, keep the plate inside the game's name band when buffs are on top (plate shorter, or drawn on the bars as a slab). Both answered by this run.

## Built (2026-11-21)
Fix A': Style/UnitAuraLift.lua lifts the Target/Focus buff row by (plate top - game name strip top + 1), only with buffsOnTop and a shown theme plate, capped at 20, strip must lie inside the frame. Hooks the row's SetPoint/ClearAllPoints (AdjustPointsOffset after the game's place) and the frame's UpdateAuras. Offline: auralift.lua 10/11 checks per client (lifted, never doubled, back when off), auraplate.lua drives the confirm run. Not yet seen in game.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug auraplate | Q1 part | hung at step 2, the test's fault: it waited for an icon with a readable place, Forever's container icons have none. Fixed: aura API check, container rect fallback, child fields logged, Buffs on Top step; offline covers a secret-icon container |
| 2 | 2026-11-21 | /cine debug auraplate | nothing | wasted, my hand-over's fault: no /reload, so the game ran run 1's code (log: 6 of 6 steps, old prompt). Target Relsie Lol had buffs |
| 3 | 2026-11-21 | /cine debug auraplate (after /reload) | Q1 (rule forever.targetframe.aura-container-place-secret); Forever has Buffs On Top; Q2-Q5 NOT: the row's place is secret | the test's faults too: went on while Edit Mode was still open (game shot shows Edit Mode), and the target was gone by the Neon shot (no target frame drawn); no check for either. Measuring the row can't work on Forever: next plan needs no row reads |
| 4 | 2026-11-21 | /reload, then /cine debug auraplate (confirm) | FIX WORKS on Forever: Neon + buffs on top lifted 6 units, screenshot shows the buffs clear above the plate (game look: same spacing). Chicken (no power bar) in a fight: plate under the strip, lift 0, buffs clear. errors +0, blocked +0. Its one FAIL was the test's: it expected a lift on every target; fixed (lift = what the plate wants) | Run 4 because run 1's plan measured the row, and the row's place is secret on Forever (unknown till run 3); run 2 wasted by no /reload. This one confirms the built fix with screenshots, waits for Edit Mode closed and the target before each look |

Still unseen: a lift above 0 being applied mid-fight (only 6 -> 0 on a target swap ran), and retail (pools path, offline only).
