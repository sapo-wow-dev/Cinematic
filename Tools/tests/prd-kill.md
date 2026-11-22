# PRD bars gone after a kill: test ledger
Goal: your personal resource bars stay up through a fight and after it, as their rows say (a player's video, 2026-11-22: both bars vanished as the target died, mid-fight, ~25 s, with Personal resource bar on Always)
Code: Frames.lua (personalPower, ~130-175, ~10563-10750; stand-in rows ~13306-13320), Effects.lua (SetPersonalPlateAlpha ~2646, SetPlateAlpha ~945, LetGoOfPlate ~2820, ApplyPlateAlpha ~2849, plate keeper ~631), Checks.lua (Reachable fight cache ~58-78), Core.lua (fightSettledWait ~3944, ~4365)
Test: Dev/PrdKillTest.lua, `/cine debug prdkill`

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Do the bars drop at a kill on our side (the user's setup), Personal resource bar on Always? | forever | NO with the user's setup (calmTime 60, warlock 12, no other addons): no drop in, at or 40 s after the kill | run 1 |
| Q2 | Which frame actually draws the bars on Forever: PersonalResourceDisplayFrame's or the own nameplate's? | forever | PersonalResourceDisplayFrame: PowerBar etc. its children; no own nameplate at all (rule forever.prd.frame updated) | run 1 step 1 |
| Q3 | Does the game remove / swap your own nameplate when the target dies (NAME_PLATE_UNIT_ADDED/REMOVED for player, plate frame changes)? | forever | NO: there is no own nameplate (0 seen); the dead mob's plate removed only | run 1 |
| Q4 | At the drop: is the own plate's UnitFrame held by us (cinematicAlpha set, alpha < 1) while both stand-ins are at 1? (a reused faded plate never let go) | forever | N/A: no own plate; the plate-reuse bug (Effects LetGoOfPlate + Reachable cache) can't reach these bars | run 1 |
| Q5 | Does ns.Reachable answer false for your own plate in a fight (cached per fight, Checks.lua)? | forever | N/A (no own plate); other plates reach true in the fight | run 1 |
| Q6 | Is PersonalResourceDisplayFrame itself hidden by the game (IsShown false) at the drop? | forever | not seen: shown the whole run (no drop to look at) | run 1 |
| Q7 | After the fight, with the health row faded: are the power bars held (ignore parent alpha) or do they fade with it (found list stale, 60 passes ~30 s since v2.1.23)? | forever | HELD: ignore true, effective alpha 1 while the frame went to 0 (before the fight and after the Calm Timer) | run 1 |
| Q9 | With the player's Keep up (health row under 80% everywhere, Personal health bar's Always, In combat and enemy ticks off, Wait at pull off): in a fight, are the power bars let go (ignore parent false) while the display frame's alpha is the secret health curve, so they fade with it? | forever | YES: power bars let go (ignore false) with the frame's entry at 0 and the stand-in at 1; gone on screen at 92% health mid-fight (shot 161418), also once just after the fight | run 4 |
| Q10 | In a fight, which prd entry sets personalPower.health last: the display frame's (target 0, curve) or the health stand-in's (up 3 s after each health change, secret health)? | forever | the stand-in's (it comes after the frame in the prd group), so personalPower.health read 1 | run 4 (state line: display entry, stand-ins, ours: health row) |
| Q8 | /cine why on the stand-in rows: "not on screen" always (no size) | both | YES from code: CinematicPersonalPower has no size/points, EntryRect nil | code, UI/Why.lua:845-861 |

## Plan tree (step 3)
- Q3 yes (own plate swapped) + Q4 yes: our fade stays on the reused frame -> let go (alpha back to 1) on NAME_PLATE_UNIT_REMOVED and on ADDED for player; check Q5 decides whether Reachable blocks it (then: forget the fight cache entry for plates on ADDED).
- Q3 yes + Q4 no: the game hides its new plate -> no fix of ours possible; Why says so; then need: which CVar/state (logged CVars).
- Q6 yes: the game hides the PRD frame -> same as above.
- Q4 yes without Q3: our alpha on the own plate goes wrong mid-fight -> trace SetPersonalPlateAlpha callers with the log's stand-in alphas.
- Q7 bars not held: rescan the bars on plate events / by time, not passes.
- Q1 no drop: run again in the player's place (Naga mobs, mage) or ask the player for the log; Why fix (Q8) goes in anyway.
All branches' facts are in run 1's log: plate events, plate identity, cinematicAlpha, Reachable, PRD frame shown, bars' visible/alpha/ignore, stand-ins, CVars.

## After the player's log + profile (2026-11-22)
Their profile (Caster 2): prHealthPrd 0.8 linked through all columns, cineShow.prd off, prdpower on Always, power row 1 / 1 (linked) / 1, fightWaitPull off, Platynator loaded. Suspect: in fights health is secret, so the display frame (an entry of the prd group) gets the game's 80% curve as its alpha, while the health stand-in (same group) is up for 3 s after each health change (HealthNotFull's guess). personalPower.health is whichever of the two ran last: at 1 with the power row at 1, personalPower.Apply lets the power bars go, and they then fade with the frame's curve (gone while health is over 80%). Plan: Q9 yes -> the hold goes by the display frame's own state (held whenever the frame's alpha isn't ours at 1, or its entry is below 1), not the last prd entry; Q9 no -> Platynator (not installed here, source not public): ask the player to try with it off.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | `/cine debug prdkill` | Q1-Q7: no drop; bars are PersonalResourceDisplayFrame's, no own plate; power bars held while the health row faded | Q1 in the player's setup: our settings (calmTime 60, no addons, warlock) aren't theirs. The video's Why says "just out of combat (Calm Timer)" ~27 s after the kill, so their Calm Timer isn't 0. Next: their profile (Share string) + their addons (DynamicTooltips Forever, Attune, Auctionator...) |
| 2 | 2026-11-22 | `/cine debug prdkill` (the player's Keep up) | none of Q9-Q10: no drop; in the fight both prd entries and the stand-ins stayed 1.00 (the fight showed the row), after it the health row faded at ~26 s and the power bars were held (ignore true) | Q9-Q10: the test left the Personal health bar's In combat tick on (theirs: combatShow.prd false, enemyShow.prd false), so the secret-curve path never ran. Also the sampling went quiet at 52 s (an error the pcall swallowed; now logged). Run 3 sets both ticks off |
| 3 | 2026-11-22 | `/cine debug prdkill` (+ their In combat / enemy ticks off) | nothing: wasted by the test | every sample failed from the first tick (PrdKillTest.lua:103, a visible bar's GetEffectiveAlpha came back nil, compared to a number; run 2's silence at 52 s was the same). Fixed: non-numbers read as unknown; offline now fakes a nil effective alpha and a let-go drop |
| 4 | 2026-11-22 | `/cine debug prdkill` | Q9, Q10: REPRODUCED, 3 drops (2 in the fight, 1 after), each: health stand-in 1.00, display entry 0.00, power bars let go | none. Fix: Frames.lua personalPower.health = the lowest of the prd entries' alphas, not the last one's |
| 5 | 2026-11-22 | `/cine debug prdkill` (confirm the fix) | FIXED: same split in the fight (stand-in 1.00, display entry 0.00) now reads health row 0.00, power bars held (ignore true) the whole fight and after; no drop; the bar on screen at the end (shot 162437) | none. Note: a held bar's own alpha reads secret (eff nil) after a fight, though drawn: Drawn() can't tell, so the follows check (ignore parent) is what catches a drop |

Budget: run 4 because runs 2 and 3 were the test's fault (In combat tick left on; a nil compare that silenced the samples), not new questions. Run 4 asks the same Q9-Q10 with the same one kill.

## After run 1
Calm Timer 0 checked (user's idea, 2026-11-22): mid-fight the rows go by In combat (ShareNow col 1, `fighting` from the game), so 0 can't drop them there; `portraitAllowed` (Frames.lua:12704) is false at 0 even mid-fight (`0 < 0`), but nothing mid-fight hangs on it. And the video's Why line rules 0 out for this player: InCalm() (Frames.lua:4759) is false at 0, and it said "just out of combat (Calm Timer)" ~27 s after the kill.
