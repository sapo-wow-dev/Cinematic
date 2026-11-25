# CDM Both (cooldown + DoT): test ledger
Goal: a spell with a cooldown and a DoT shows either, or both: the row's choice DoT / Cooldown / Both (replaces Own cooldown), and Both's look picked on Style > Cooldown Manager: ring, bar under, corner number, edge pips, row pips (4 / 8 / 12). The user, 2026-11-25: "more choices the better".
Code: Dev/CdmBothTest.lua (probe); to build: UI/CooldownRing.lua (pips/ring from time), Frames.lua (notBuff -> 3-way), UI/CooldownGrid.lua, Style/CdmStyle.lua, Media/make_cdm_ring.py (square edge art)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | C_Spell.GetSpellCooldownDuration(id, true) in a fight: an object? HasSecretValues? | forever | YES an object (plain userdata), every read on it SECRET in a fight (percent, remaining, total, HasExpired, IsZero, EvaluateRemainingPercent with our plain curve too), no errors | run 1 |
| Q2 | GetRemainingPercent's scale (0-1 or 0-100), read plain after the fight | forever | 0-1 (0.847 with 152 of 180 s left); out of a fight A, B, C drew it right (shot: 7 of 8 pips at 83%) | run 2 |
| Q3 | Way A: EvaluateRemainingPercent(our step curve) into SetAlpha in a fight | forever | YES (result secret even with a plain curve, but SetAlpha takes it; shot 7 of 8 at 83%) | run 3 |
| Q4 | Way B: GetRemainingPercent (secret) into the ring's StatusBar pips | forever | YES (shot) | run 3 |
| Q5 | Way C: StatusBar:SetTimerDuration(dur) drains by itself in a fight | forever | YES (shot) | run 3 |
| Q6 | Way D: SetFormattedText("%.0f", GetRemainingDuration()) in a fight | forever | YES (shots 150 then 146) | run 3 |
| Q7 | The DoT's time apart from the game's swipe: GetAuraDuration(unit, icon.auraInstanceID) | forever | NO: errors every pass in a fight ("Auras cannot be accessed when secret while tainted"), the icon's aura id secret | run 1 (85 of 85) |
| Q7b | ... from the times the game's icon keeps (cooldownStartTime / cooldownDuration / auraDataCached.expirationTime, CooldownViewer.lua:882): E1 our Cooldown:SetCooldown(secret), E2 StatusBar start..end set to GetTime(); E3 the game's text copy (drew nothing in run 1: CVar off?) | forever | E1 NO (SetCooldown refuses secret times, 84 of 84); E2 bar YES (drains, shots); E3 copy YES (20 then 16, CVar countdownForCooldowns 1) | run 3 |
| Q8 | Cost of a pass (8 curves + ring + bar + text + DoT) | forever | 0.23 ms in a fight, 0.17 out (10 passes a second) | run 3 |

## Plan tree
- Q3 or Q4 yes: pips (edge + row) and ring from that way; both kept if both work (A plain is cheaper: no StatusBars). Q2 sets the curve/size scale.
- Q3 and Q4 no, Q5 yes: smooth ring/bar from SetTimerDuration only; pips only out of fights (say so to the user).
- Q7 aura yes: bar under / corner number get the DoT from it. Aura no, copy yes: corner number copies the game's text; bar under = cooldown on the swipe, DoT on... no bar source: bar under then shows the cooldown bar only (ask the user).
- Q6 no: corner number from the copy only.

## Build (2026-11-25)
UI/CooldownBoth.lua: rows with Shows = Both (notBuff "both"; true = Cooldown, the old swap, now only == true) draw the
spell's cooldown over its DoT while the DoT shows: ring (CdmRing<n>_i art), edge pips, row pips (4 / 8 / 12), bar
under (SetTimerDuration), corner number (GetRemainingDuration, alpha by curve). DoT always the game's swipe + number.
Style > Cooldown Manager third folder tab "Cooldown + DoT": Look, Pips, Color, Custom color, a preview. Grid: Shows
(Buff/DoT, Cooldown, Both), hidden on spells with no cooldown of their own. Offline Tools/offline/cdmboth.lua ALL PASS
(28). Game: /cine debug cdmboth steps 4 page, 5 built (a DoT icon given Perception's cooldown: no warlock spell has both).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-25 | queue q912a cdmboth | Q1 (secret object, no errors), Q7 NO (GetAuraDuration errors), A-D draw with no errors, 0.18 ms per pass | Q2-Q6 visually: the cooldown never ran. The test's fault: it took Healthstone (the only 8 s+ cooldown in a level 12 warlock's bars; costs one, the user's issue) and went on after any two casts. Run 2: the shortest spellbook cooldown, a "Both cast" button, a verdict that the cooldown runs after the fight, the countdown CVar on, Q7b ways |
| 2 | 2026-11-25 | queue qaa2b cdmboth | Q2 (0-1), out of a fight A/B/C draw right (shot) | the fight step: sat on a "Both cast" button the user didn't take ("stuck. i did what it asked"), skipped. The test's fault: a click where it could see for itself. Run 3: the cooldown seen running out of a fight (plain), then the fight + DoT on its icon, no clicks; the ring's own percent text hidden off D |
| 3 | 2026-11-25 | queue q5a88 cdmboth | everything: A/B/C/D draw in a fight (rule forever.duration.spell-cooldown-draws-in-fights); DoT time: bar + text copy work, our Cooldown frame doesn't (rule forever.cdm.dot-time-from-icon-fields) | nothing open. Probe done in 3 runs; next run = the built feature |
| 4 | 2026-11-25 | queue q65b2 cdmboth | page: tab opens, preview clear, all 6 looks right in the preview (shots), tab off = Ring 8; built: bar under and corner number draw on the real icon in a fight (shots), the game's DoT kept, 145 draws 0 errors | ring, edge and row drew NOTHING in the fight (shots) though their verdicts passed: first made in a fight, the icon's width secret, no size. Fixed: the size kept per icon from when it reads plain (before the DoT is up); offline check with sizes unreadable in a fight; the verdict now needs a size. Run 5 = the built step again |
| 5 | 2026-11-25 | queue q472f cdmboth | built: all 5 looks sized (50) and drawn on the real icon in a fight, beside the game's DoT (shots: ring, edge, row, bar, corner 162), 160 draws 0 errors | the step's FAIL is 2 blocked CheckInteractDistance calls from Plates/PlateParts.lua -> Frames.lua:4936 (the range rings work in another session, uncommitted), not this feature. Every step proven; `/cine debug cdmboth full` once before the commit |
| full 1 | 2026-11-25 | queue q686c cdmboth full | probe, page and bar/corner all PASS again | ring, edge, row had NO size: the Cooldown Manager hidden out of the fight, and the walk (EachCooldownIcon without all) skipped hidden icons, so the size was never read before it (run 5 had the bar up). Fixed: the walk takes hidden icons, and an icon with no size takes the last one read; offline check with the icon hidden till the fight. E1 (proven NO) counted as a FAIL: now logged, not a verdict. 2 blocked again: range rings (Frames.lua:4936), not this feature |
| full 2 | 2026-11-25 | queue qd5a0 cdmboth full | everything for this feature: probe, page, all 5 looks sized in a fight (159 draws, 0 errors) | the DoT's icon had no size of its own: it took 44, another bar's (run 5 read its own 50). Fixed: every icon's size read on each walk, Both or not, the fallback per bar; offline checks; a verdict for its own size. Errors: blocked x36 CheckInteractDistance, Frames.lua:4936 (range rings, 88e355c): sent to the Range Indicator session (its rule forever.range.plates-in-combat misses this case). The kit now inspects errors itself (Dev/TestKit.lua) |
| 6 | 2026-11-25 | queue q93e0 cdmboth | built: the DoT's icon's own size (50) read before the fight, all 5 looks drawn at it, 161 draws 0 errors; kit inspection: 0 errors during, 0 blocked (the range rings fixed by the Aggro range session) | nothing. Every step proven: probe in run 3, page in run 4, built here; the full runs q686c / qd5a0 covered all steps around these fixes |
