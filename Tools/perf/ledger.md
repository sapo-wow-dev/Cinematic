# Performance ledger

Every fix from the /perf skill: what, expected saving, commit, measured
result after the next recording. Older history (2026-10-30 to 2026-11-19) is
in the cpu-profiling memory; its leads still open are copied below.

Recordings: `python Tools/perf/analyze.py --all` keeps each one in
Tools/perf/history/ (local, not committed) and writes a report to
Tools/perf/reports/.

## Baselines

| Date | Client | Kind | Real ms/frame | KB/s | Over 5 ms |
|------|--------|------|---------------|------|-----------|
| 2026-11-19 07:14 | forever | CineMode, calm, solo, 40 plates | 1.232 | 120 | 1.2% |
| 2026-11-22 01:40 | forever | CineMode, calm, solo, 5 plates | 0.416 | 24 | 0.9% |

## Fixes

| Date | Issue | Change | Expected | Commit | Measured |
|------|-------|--------|----------|--------|----------|
| 2026-11-22 | 1. FriendRowWanted full settings scan x6 / 10 s | Row column keys listed once (ns.plates.FriendRowsTicked), relisted on a new key (ns.db __newindex); test friendrows.lua: same answers on the real 8,322-key settings, 19x faster offline | the 6-9 ms UpdatePlates spike every 10 s gone | - | 02:28: UpdatePlates worst 9.01 -> 2.11 ms in 120 s. Confirmed |
| 2026-11-22 | 2. Combat list kept 2 s | 10 s while ns.SlowChecks (SHOWN_STEADY_SLOW); test combatshownhold.lua | ~0.7 ms off most frames passes (3.3 -> ~2.6) | - | 02:28: GetCombatShownFrames 0.82 -> 0.56 ms a pass, UpdateFrames 3.30 -> 3.15. Partial: still worked out on most passes (an input it compares changes: likely the rule facts stamp while moving, 20% of frames) |
| 2026-11-22 | 3. Idle tick held busy by every wake | Only idleTick.HARD_WAKE holds Settle(); "tick busy: why" counts in recordings; test idletick.lua | ~0.085 ms a frame calm in CineMode (26 -> ~10 ticks/s) | - | 02:28: no change (24 ticks/s): a shown GameTooltip held the full pace on 56% of frames, moving 20%. The wakes it covers now under 3%. Blocked by the tooltip hold |
| 2026-11-22 | 0. Favorites page left shown with no parent: "settings open" from login (ns.OurSettingsShown), so ns.SlowChecks off all session till the window was opened once | canvas:Hide() before RegisterSubpage (UI/Favorites.lua) + WatchSettingsCanvas skips parentless canvases (Options.lua); test settingsclosed.lua | every idle saving back from login | - | 02:28: slow checks on 92% (was 2.4%). Confirmed. Found by the 02:20 recording: slow checks off 97.6% "settings open", 0.79 ms/frame |
| 2026-11-22 | 5. A shown GameTooltip held the tick's full pace (56% of frames in a city), blocking fix 3 | Held only while the Tooltips page handles tooltips (idleTick.TooltipHolds + ns.TooltipsHandled; its ns.UpdateTooltip is the only tick step reading it); test idletick.lua (tooltip cases) | fix 3's saving: ~24 -> ~10-14 ticks/s standing still (moving still holds it, 20%) | - | 13:33 (open world): no "tooltip shown" busy reason left. Holds now: fight 48%, settling after PLAYER_TARGET_CHANGED 39% (expected) |
| 2026-11-22 | 6. Calm Timer worked the fight frames list's rows out on every pass (4-6 ms, 8/s; 10 of 12 slow calls in the 13:33 fight run) | tickTables.fightTicks kept while `fighting` (fight or Calm Timer), made afresh once at PLAYER_REGEN_ENABLED, which now also stamps lastCombatAt (Frames.lua); test combatshownhold.lua: 298 rows -> 0 a Calm Timer pass | the 9-13 ms Calm Timer hitches down to ~5-8 ms (the list's ~4 ms gone; the rest is UpdateFrames' hidden 6 ms) | - | 14:11 (fights 79%): rows worked out down 85-92% (IsCineShowOn 4.13 -> 0.63/frame, IsCombatShowOn 3.21 -> 0.25), but GetCombatShownFrames 0.42 -> 0.46 ms a call, worst 6.3 -> 10.5. **No time saved**: the rows' ticks were not its cost. Kept (harmless, fewer calls) |
| 2026-11-22 | 7. Quest walk (Show just that quest) walked the game's whole tracker every frames pass, ~0.8 ms, settled walks changing nothing | Walk only while the others fade, the tracker's own alpha changes, 2 s after a quest log/watch/zone/scenario change or a reveal (focus.watch, Focus), a timer / Close the gaps / others up, and once a second else; skipped passes reuse the last walk's answers (Frames.lua QuestFocusTick); test questwalkskip.lua; bench questwalk now settled with questRevealTime 60 | ~0.8 ms off each frames pass while a quest is shown alone (1.55 -> ~0.8 ms in the bench) | - | 15:31 perf: walked 47 of 47 passes, no gain: Close the gaps (questRevealCollapse, on for the user) kept every pass walking. Now its copies stay as drawn between walks too; walk reasons counted ("quest focus: walked for ..."); the perf test fails if settled passes don't mostly skip. **15:40 perf: quest walk 1.071 -> 0.035 ms a call (-97%); held 10 s it walked 10 of 56 passes (3 tracker changes, 7 once a second), the game putting back 0 of 200 parts. Confirmed.** |
| 2026-11-23 | 8. Friendly rows' key list relisted (~8,300 keys, 3.8 ms) on the first plates pass out of every fight: the fight sound cue adds combatHeldAmbience, and ANY new key marked the list stale | Only a new plate.../name... key marks it (Effects.lua NewKey); test friendrows.lua (+4 checks: a cue's key 3 times, another new key: list kept; new name/plate keys: relisted and seen) | ~3.8 ms off the slow frame at each fight's end (6 in the 17:10 run) | - | 17:57 normal run (fixes 8-10 loaded, 17:41 reload): UpdatePlates worst 1.43 ms, UpdateCVars 3.89 (the name sets, lead 1). Only ONE fight end in it: likely, not confirmed |
| 2026-11-23 | 9. Plates pass never quiet in the Calm Timer with a kind ticked for fights (~27 full passes a second, ~0.23 ms a frame deep) | Kinds held at 0 after a fight count as settled like a fight's; SameAsBefore has the Calm Timer in its inputs (its end brings a pass at once); card 2026-11-23-calm-plates-settle.md, test calmplatesmatrix.lua | ~0.08-0.15 ms a frame real in Calm Timers | - | - |
| 2026-11-23 | 10. Target of target's frame dressed whole twice a frame (its OnUpdate resets the power bar's fill and color; ~38 StyleLook a frame) | A game set on a bar with nothing of ours dresses the frame once 0.2 s later (at once for a new unit, a green mana color, or a bar with ours); card 2026-11-23-tot-redress.md, test totredressmatrix.lua | est. 0.06-0.15 ms a frame real while a ToT shows (~0.48 deep) | - | Not measurable in a normal run (DressFrame untimed). Limit: an enemy ToT's name is secret in Forever fights (secrets-combat rule): then still dressed at once, no saving |
| 2026-11-23 | 11. Plate parts keeper put back every faded part of every plate each frame (~17 a plate; 0.134 ms a frame at 15 plates, 18:34 deep run), gone plates' parts too (old leads 5, 4) | Only parts the game fades itself polled each frame: threat glows (animations), the cast bar where there's no CastBarsContainer (the game fades the bar inside, read in the Forever source); the rest swept every 0.5 s ("plate parts: put back by the sweep" counts any the game did set); a removed plate lets go (Plates/PlateParts.lua); test platekeeper.lua | ~0.10-0.11 ms a frame at 15 plates (60 of 135 parts a frame offline); more after a long session | - | - |
| 2026-11-23 | 12. Camera speed writes: ns.SetHeldSpeed 0.76 ms a call (the game's XP bar redraws on every CVAR_UPDATE, our bar hooks after), ~7/s in the Chat Cam's drift | Speed step 2% -> 5% in ChatCam, QuestCam, ShowMe, the fly-by (as CameraScripts); test speedwrites.lua (slow drift 220 -> 100 writes, a quick swing 122 -> 89) | ~0.03-0.04 ms a frame while the Chat Cam drifts; less on quick swings | - | - |
| 2026-11-23 | 13. Shoulder Cam FormNow made a closure per read (~100/s with the cam on) | One ReadForm function (Camera/ShoulderCam.lua); test shoulderformread.lua: 0.09 KB per 1000 reads | ~6.6 KB/s with the Shoulder Cam on | - | - |
| 2026-11-23 | 14. ns.FindCameraScript made every built-in camera script to find one (~220 KB a look) | Makes only the one asked for (Camera/CameraScripts.lua BuiltinScript); test findcamerascript.lua: same script as the list's for every id, 0 KB a look (the list 230 KB) | the 220 KB garbage bursts per camera start / script page look; lowers the floating memory figure | - | - |
| 2026-11-23 | 15. Visual Effects rows asked every tick in CineMode (the cinematic bypass); 4 -> 10 effects on 11-23 (inn, haze, frost, rainlens, lightning, density): ns.RowOnNow from the tick 0.2 -> 6.4 a frame, with RuleFacts ~0.18 ms a frame (18:53 deep run) | Every EFFECT_ASK (0.1 s) in CineMode too, at once on a fight start/end, CineMode on/off, the effects demo and its end (Core.lua effectAsk.Due); test effectask.lua: 20 asks in 2 s at 80 fps (was 160) | most of ~0.18 ms a frame deep while the tick runs at full pace (moving, tooltip, fading) | - | - |
| 2026-11-23 | 16. Centered Cooldown Manager bars: PlaceBar made two closures (Goal, FadedGoal) per bar per pass, ~0.7 KB a bar; 10 passes a second in fights (utility = "recharge" keeps `any` on), up to 3 bars: ~21 KB/s (19:47 normal fight run, UpdateReadyOnly 20.8 KB/s) | Made once on shownIn (Frames.lua is at 200 locals), the bar's numbers in shownIn.placing; test centerbar.lua: 528 bar layouts, every goal the same as the old code (kept in the test), 1000 bars 0 KB (old 703 KB) | ~14-21 KB/s in fights | - | - |
| 2026-11-23 | 17. Vitals drew every layer every frame with secret health (fights on Forever: it can't sleep, can't tell full from low), "Vitals: apply" 0.092 ms a frame at 113 fps | Drawn every SECRET_DRAW (1/40 s) then, at once on a hit, a flash, a test or the quick look; Apply's motion goes by GetTime, so it moves as fast (Atmosphere/LowHealth.lua); test vitalsdraw.lua: 40 draws a second secret, 120 plain, a hit drawn the frame it lands | ~0.06 ms a frame in fights at 113 fps | - | - |
| 2026-11-23 | 18. Timers on 11-23's untimed code ("not wrapped" 0.39-0.56 ms) | "Unit frame dress" + "Unit power keep" (Style/UnitStyle.lua, the best suspect), "Cooldown Missing pass"/"show", "Drain ring watcher", "Plate mouseover watch", "Mana Vision events", "Feature loop gates" (Profiler.lua wraps ns.SyncFeatureLoops), "Detached parts walk"; Chat's copy watch set once till cleared (was per chat line); test newtimers.lua | names the untimed cost in the next normal run | - | - |
| 2026-11-22 | 4. FindQuestieIcon closure + table per plate | Children as varargs (PickQuestieIcon); test questieicon.lua: 0 KB per 1000 looks | ~14 KB/s at 40 plates, with Questie loaded only (the sweep is gated on QuestieLoader; never ran without it) | - | - |

## Open leads

First /perf dig, 2026-11-22 (4 agents, each claim checked in code):

1. ns.plates.FriendRowWanted (Effects.lua:3951) goes over all of ns.db
   (~8,300 keys) 6 times every 10 s out of fights: the 5.7-9 ms UpdatePlates
   spikes. Fix: cached candidate key list, rebuilt on profile load.
2. GetCombatShownFrames kept only 2 s (SHOWN_STEADY, Frames.lua:5057) while
   its inputs hold: ~0.8 ms of each 3.3 ms UpdateFrames pass. Raise while
   ns.SlowChecks.
3. Idle tick never quiet: any non-soft wake (chat lines, peeks) or a shown
   GameTooltip holds the full 0.03 s tick (Core.lua:3995, 4054): 26.6 ticks/s
   instead of ~10. ~0.085 ms a frame.
4. FindQuestieIcon (Plates/PlateParts.lua:1455): closure + {GetChildren()}
   per plate per sweep, ~14 KB/s at 40 plates.
5. Plate parts keeper keeps parts of removed plates in `held` (REMOVED
   doesn't let go): 0.045 ms a frame at 5 plates. Check the pool size first.
6. CooldownFlash OnUpdate runs every frame with nothing recharging: 0.035 ms.
7. Small garbage: NodeSweep.lua:2636 note string and `nodes = {}` every pass;
   FrameLinks.lua:112/128 `claims[part] or {}`; GetNamePlates() up to 6 times
   a pass.
8. Later, bigger: UpdateFrames fast path for plain settled entries (~0.5 ms a
   pass), needs an offline equivalence test.
- Latent: platesDirty cleared only when plates are filtered (Effects.lua:4171).
- Timers to add (cost nothing unprofiled): ns.plates.FriendWants/FriendRowWanted/
  OffscreenWhy, UpdateLockedPlates, duels.Sync/Update, PlateParts watchers.
- Fights not recorded since 2026-11-11 (~1.1 ms/frame then).
- Analyzer note: a deep run's "not timed" gap is mostly the profiler's own
  wrapper cost; a normal (not deep) run gives the real unwrapped figure.

2026-11-22 02:20 recording (fixes 1-4 in, but slow checks off: not comparable):
UpdatePlates worst 4.76 ms (was 9.01), WarmCombatShown 0.6 ms a call x 0.52 a
frame (slow checks off: renewed every 0.2 s), UpdateFrames 2.36 ms x 4.6/s.
New lead from the "tick busy" counts: **GameTooltip shown on 61% of frames**
held the full tick pace (Core.lua ns.Pace, Flag(GameTooltip:IsShown())), moving
23%; the wakes fix 3 covered are now under 4%.

2026-11-22 02:28 (12 s after /reload): 0.540 ms/frame real, 49.6 KB/s. Not like
for like with 01:40 (0.416, 2 min after login, no name-only plates): the slot
build ran all through (ns.SettingSlot/MarkRowDefault ~90 calls a frame, mostly
wrapper cost; ns.ApplyModules + ConvertOffGrids ~20 KB/s), and name-only plates
ran "Plate names" every frame (0.038 ms, 14 KB/s for 4 plates). The analyzer
now warns about recordings started within 180 s of a login.

Next leads (ranked):
1. (done: fix 5) GameTooltip hold.
2. GetCombatShownFrames still worked out most passes: find which compared
   input moves (count each in Kept while profiling).
3. "Plate names" (Plates/PlateParts.lua:3342): 14 KB/s for 4 plates (DrawName
   every FAR_CHECK, pcalls per plate).
4. Plate parts keeper 0.045 -> 0.103 ms a call at similar plates: held parts
   of gone plates grow over a session (old lead 5).

2026-11-22 13:33 Forever, open world, fights 44% of frames (first fight run
since 11-11): 0.558 ms/frame real, 70 KB/s, 2.0% of frames over 5 ms, worst 14.
- UpdateFrames 3.27 ms a pass x 7.2/s (worst 12.5), 24 KB/s: 10 of 12 slow
  calls are in the Calm Timer, each with GetCombatShownFrames 4-6 ms. The
  fight ticks cache (tickTables.fightTicks, Frames.lua:4979) holds only while
  `fight` (lockdown) and is cleared at PLAYER_REGEN_ENABLED, so every Calm
  Timer pass works every row out again, 8 times a second.
- UpdateFrames hidden: 6.3 ms of a 10.2 ms call untimed (its locals).
- ns.UpdateEntryClicks 534 calls/s, 6.8 KB/s (a clicksOff table per fade-out,
  plus ClicksOff's walk).
- ns.IsMinimapRevealed 7.4 KB/s (old lead 7: note string + nodes = {}).
- ns.QuestFocusTick 1.5 ms in several slow calls.
Analyzer: kinds now by fight share from the counts (not the start state).

2026-11-22 14:02 Forever, open world, normal UI (CineMode off: "stays off while
moving"), fights 22% of frames: 0.246 ms/frame real, 16 KB/s, 4 of 9,559 frames
over 5 ms, worst 7.3. Fight cost with CineMode off is low. Fix 6 not measured
(the list is only asked in CineMode).
- ns.RefreshUnitStyle (Style/UnitStyle.lua:2706): 1.25 ms a call, 0.4/s, worst
  2.2; 2 closures and 8 string builds a call.
- Camera rows chain (ns.CameraRowsScripted -> SceneLead -> TriggerRowNow ->
  TriggerSetting, Camera/CameraRows.lua): ~3 KB/s, CameraRowsScripted makes a
  table each call.
Analyzer: fight share now over the frames the slow checks were asked on (they
aren't asked every frame out of CineMode; 13:33 reads 78%, not 44%), and a
Dev/ test's wrapper is no longer given as a function's source.

2026-11-22 14:11 Forever, open world, CineMode, fights 79% (12 s after /reload):
0.518 ms/frame real (13:33: 0.558), 68 KB/s, 1.1% over 5 ms (was 2.0%), worst
28.8. Slow calls: 10, still UpdateFrames 8-17 ms with GetCombatShownFrames
4-10 ms in most.
- GetCombatShownFrames' spikes are not its rows' ticks (fix 6). Left in it:
  ns.RuleShows per row (6.4 calls a frame, ~0.5 ms a list) and untimed locals
  (PlaceListsHere, KeptHere/IsListOn in the extra frames loop, the spellbook
  loop). Next: time those parts (reassign the locals through ns.Profiled, no
  new locals) and record again; no more guessing at it.
- ns.UpdateEntryClicks 1.2-2.1 ms in single calls (slow call lines): the
  ClicksOff walk over a frame's children as it fades out.

Timers added 2026-11-22 (cost while not recording: one ns.profiling check a
part): ns.ProfileAdd(name, ms, kb) in Profiler.lua records a code-timed part
under the running section (and names it in slow call lines from 0.5 ms).
- GetCombatShownFrames: "combat list: ..." fight target and cast, place
  lists, fight ticks and rule facts, rows' rules, rows' ticks, rows' fight
  hold, rows other, spellbook bars, added frames; and change check (Kept).
  Test: combatshownhold.lua (listed, add up to no more than the list, none
  timed while not recording).
- ns.UpdateFrames: its /cine debug framepass parts go to the profiler while
  recording ("frames pass: switches, combat list, rest of setup, mouse hover,
  peeks and minimap reveal, cooldown bars, groups, unit frame parts, death and
  minimap, targets, applying, after"). Not testable offline (the pass doesn't
  return on the stand-in): the next recording shows them.
Next recording: a CineMode fight run, 3 min after /reload.

2026-11-22 14:41 Forever, open world, CineMode, calm (0% fights; 27 s after
/reload): 0.305 ms/frame real, 40 KB/s, 0.2% over 5 ms (30 of 12,982), worst
15. The new timers work (slow calls name the parts).
- A full combat list (calm, not kept): ~3.4 ms = rows' ticks 1.8 + rows'
  rules 1.5; every other part under 0.15 ms. So out of fights the list is its
  ~300 rows, half ticks, half rules.
- Frames pass parts, a pass: targets 0.84 ms, mouse hover 0.58, rest of setup
  0.23, combat list 0.26 (mostly kept), applying 1.09 (one 12.6 ms, the
  recording's first pass).
- One-offs in the first 20 s: UpdatePlates 13.2 ms, UpdateFadingFrames 10.4 ms
  (likely login work; check in a run started 3 min after /reload).
Still wanted: a CineMode fight run with the timers, for the list's 4-10 ms in
fights.

2026-11-22 14:50 Forever, open world, CineMode, fights 81% (12 s after /reload):
0.335 ms/frame real (14:11: 0.518; 135 fps here vs 89), 70 KB/s, 0.5% over
5 ms (was 1.1%), worst 23. Slow calls (8-14 ms) = combat list 4.4-5.9 +
applying 3-6, at fight ends.
- A full list: rows' rules 1.4 ms every rebuild, rows' ticks 3.5 ms at the
  one rebuild a fight's end (0.28 on average: fix 6 holds). The rest < 0.5.
- But in a deep run each row calls 3 wrapped ns functions (RuleShows,
  RuleTest, FollowKey, ~1.5 us each): 300 rows x ~4.5 us = ~1.35 ms, nearly
  all of "rows' rules". The list's spikes are mostly the profiler's own cost.
- "applying" 5-6 ms at a fight's end: ~170 frames starting to fade at once.
- Frames pass "targets" 1.2 ms a pass on average (the steadiest part).
Next: a NORMAL fight run (`/cine profiler 120`, no deep) for the real spikes
(the game's Over5Ms) before any more list work. Analyzer and /perf skill now
say so for deep runs.

2026-11-22 15:01 Forever, NORMAL run (no wrappers), open world, CineMode,
fights 30%, 82 s after /reload: **0.421 ms/frame (the game's figure), 35 KB/s,
29 of 13,971 frames over 5 ms (0.2%), none over 10, worst 8.1 ms**; one slow
call (8.1: applying 3.7, targets 1.6, combat list 0.9).
- Combat list real: 0.12 ms a call, worst 1.9 (deep read 4-6). Done with it.
- Frames pass: 2.5 ms a pass x ~6/s. "targets" 1.26 ms a pass = half of it,
  the biggest real part (~170 entries, ~7 us each): old lead 8, the fast
  path for plain settled entries. "applying" 0.61 (worst 4.3 at fight ends).
- Fixed: the timers gave the whole pass's / list's garbage to "frames pass:
  after" / "combat list: added frames" (now time only; the parent rows carry
  it). Analyzer: deep and normal runs are now different kinds.

"targets" dug 2026-11-22: it isn't the ~170 plain entries. In the 14:50 fight
run ns.QuestFocusTick (Frames.lua, Quest tracker's Show just that quest) took
0.72 of targets' 1.22 ms a pass (60%); calm, 0.005. On about half the passes
it gets past its early return and ApplyFocus walks every section, block and
bar of the game's tracker. A skip-when-settled fix needs to know whether the
game puts block alphas back itself (no engine rule says): so a probe first.
- Probe (profiling only): counts "quest focus walks: <why>" (a quest shown
  alone / a tracker timer / close the gaps / others held up / fading back)
  and "settled"/"fading"; times "quest focus: game's tracker" and "addons'
  trackers"; ns.FadeRelative counts, for the walk's parts (ns.fadeRelativeTag),
  "the game changed it" / "set" / "already so". Test: questwalkprobe.lua.
- Next: a NORMAL fight run with quests tracked. If the walks are settled and
  "already so" with "the game changed it" near 0, walk only while fading or
  on a tracker change; else walk on the game's redraws only.
- Note: Frames.lua's main chunk is at Lua's 200 locals (a new local
  function broke the load; luacheck doesn't see it). Compile check:
  python -I -c "import lupa.lua51 as l; ..." loadfile.

2026-11-22 15:11 Forever, NORMAL, open world, CineMode, fights 69%, 64 s after
/reload: **0.302 ms/frame, 39 KB/s, 11 of 18,669 frames over 5 ms (0.1%), none
over 10, worst 7.05**: the best fight run yet. No quest walk at all (no probe
counts): frames pass 1.64 ms a pass, targets 0.47 (15:01: 2.52 and 1.26), so
the walk is ~0.8 ms of a pass when it runs. The probe still needs a fight on
a tracked quest's mobs (the walk runs while Show just that quest focuses one).

Benchmarks, 2026-11-22: `/cine debug perf` (Dev/PerfTest.lua) times the hot
code in a state the test sets up (CineMode on, a quest revealed alone by
ns.PerfQuestReveal), one call a frame x 60, exact KB a call, with ProfileAdd
parts: frames pass, combat list afresh / kept, plates pass, friendly plate
rows, quest walk settled; and a 10 s live hold of the quest walk with the
probe's counts (the answer the walk fix waits on). Results in
CinematicDB.perfResults / perfHistory; `analyze.py --bench` compares each
with its last run. Offline: Tools/offline/perftest.lua.

2026-11-22 15:26 first /cine debug perf (Forever, Teldrassil, CineMode, 170
frames, 0 plates, 38 fps): 9 pass, 15 s, nothing to do. Per call:
| Step | ms | p95 | worst | KB |
|---|---|---|---|---|
| frames pass | 1.552 | 2.06 | 2.38 | 0.71 |
| combat list afresh | 0.793 | 0.90 | 1.05 | 0.30 |
| combat list kept | 0.069 | 0.11 | 0.19 | 0.00 |
| plates pass | 0.049 | 0.07 | 0.11 | 0.01 |
| friendly plate rows | 0.114 | 0.07 | 3.81 (one relist) | 0.40 |
| quest walk settled | 0.822 | 0.98 | 1.14 | 0.24 |
Frames pass parts: targets 0.55, applying 0.50, setup 0.13, hover 0.08,
combat list 0.07. List afresh: rows' ticks 0.37, rules 0.15, other 0.11.
**Quest walk answer:** held 10 s, 23 settled walks touched 413 parts: the
game changed 0, we set 0, all "already so". Settled walks change nothing.
Caveat: no quest progress in those 10 s, and progress redraws the tracker
(blocks reused): walk while fading, and for a moment after a tracker change
(QUEST_LOG_UPDATE, a reveal), plus a slow safety walk; skip the rest.
Expected: ~0.8 ms off each frames pass while a quest is shown alone.

2026-11-22 15:31 second /cine debug perf (Forever, 109 fps): every step 9-17%
slower than 15:26 at 38 fps (one run each: noise between runs is that big;
compare steps within a run, or several runs). Quest walk 0.933 ms, walked
47/47: the fix above was held off by Close the gaps.

2026-11-23 17:10 Forever, DEEP, open world, CineMode, fights + Calm Timer 100%
(back-to-back pulls, the Calm Timer never ended), 70 fps: 1.105 ms/frame real,
294 KB/s, 7.3% over 5 ms. /perf dig (5 agents, each checked in code):
- 145 KB/s was the Cooldown Manager drain ring's tooltip build (Lightning
  Shield, 4/s): fixed before the next run by TIP_RETRY (UI/CooldownRing.lua).
- Fixes 8-10 above. Left as leads, ranked:
  1. UnitName* name sets taken up at each fight's end and let go at the next
     pull (Effects.lua NamesOnPlates' KindShown ignores the Calm Timer): 10
     SetCVar a fight, ~8 ms. Behavior change (names through the Calm Timer):
     the user's call. Also ApplyCVarSet writes unchanged values.
  2. FadeDetached Walk: one root's whole tree in one frame (5.4 ms worst at
     fight ends) + {GetRegions()}/{GetChildren()} per node: resumable walk.
  3. QuestStandIn REBUILD 0.2 < the 0.24 s between calls: rebuilds every call
     (~7 KB/s); minimap quest look ~20 KB/s; CenterCooldownIcons' PlaceBar
     closures ~8 KB/s.
  4. Quest walk on every quest event in fights; frames pass at 4/s through
     the Calm Timer; Visual Effects rows asked every tick in CineMode (Core.lua
     effectAsk bypass): ~0.025-0.04 ms a frame each.
  5. Vitals: ~45 double-metatable look reads a frame (~0.03-0.05 ms).
- Ruled out: WarmCombatShown's 4.5-8 ms deep spikes (~0.005 ms/frame real).
- Analyzer bug: the "Vitals" section's source is found by the bare function
  name ("Update"), first match wins (Effects.lua duels.Update); it's
  Atmosphere/LowHealth.lua's Update.

2026-11-23 18:34 Forever, DEEP, open world, CineMode, calm, 15 plates, 79 fps:
0.959 ms/frame real (game 1.210, wrappers 0.251), 63 KB/s, 0.6% over 5 ms.
The AddOn list's 8% = ~1 ms at 80 fps (12.5 ms frames). /perf dig (5 agents,
each checked in code): fixes 11-14. Left as leads:
1. UpdateFrames' 1 s timer pass in settled CineMode (Core.lua CINE_SLOW_PASS):
   all ~170 entries run the whole target chain, all ending where they were;
   ~1.5 ms real a pass. Fast path for plain settled entries (old lead 8) or a
   cursor spreading it over frames; needs an old-vs-new equivalence test.
2. SetHeldSpeed: mute StatusTrackingBarManager's CVAR_UPDATE while a speed
   is held (untested for taint), or call C_CVar.SetCVar (one hook pass, not
   two); measure the split first: /cine debug cvarcost with XP bar looks on/off.
3. Memory: the AddOn list's 91 MB is about half uncollected garbage (41-61 MB
   live measured collected before). Release Cinematic.lua SavedVariables is
   6 MB, ufDriftLog alone 4.5 MB: drop it in a migration. Dev/*.lua tests
   ~4-5 MB compiled in the dev copy only. /cine debug pagecost = the collected figure.

2026-11-23 18:53 Forever, DEEP, city, CineMode, calm, 5 plates, 40 fps, 32 s
after /reload (fixes 11-14 loaded): 1.263 ms/frame real, 59 KB/s. Fix 11
confirmed: Plate parts keeper 0.034 ms a frame at 5 plates (0.10 on 11-22 at
5), no "put back by the sweep" count. Like-for-like normal runs: 11-22 15:01
0.42 ms (game) -> 11-23 17:57 1.23 ms; time no timer covers 0.13 -> 0.56 ms:
11-23's new per-frame code is untimed (weather screen effects, the Mouseover
row's hoverWatch, CooldownRing/CooldownStacks watchers, CooldownMissing
ticker, FadeDetached walker). Next: time them, then one normal run.

## Ruled out

- GetCombatShownFrames' per-row ticks as its cost (fix 6, 2026-11-22 14:11).

- Minimap sweep garbage (~410 B a point): the game's tooltip tables; only
  sweeping less often would cut it (2026-11-05).
