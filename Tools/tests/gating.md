# Gating audit fixes (2026-11-25): test ledger
Goal: a page, tab or part switched off stops everything on it in the real game (nothing runs, shows, or stays held), and comes back on.
Code: the fix cards' files (Tools/audits/2026-11-25-*.md); test Dev/GatingTest.lua (`/cine debug gating`), offline Tools/offline/gatingtest.lua
Player actions: one Reload click (step 10). No walking, no camera turning. Run from a town (NPC plates).

The questions are the cards' "not proven offline / in game" items. **open** = this run reads it;
**needs-state** = logged as SKIP "needs <state>" (a state the test can't make hands off); **answered** = from a real log.

## Questions
| # | Card | Question | Client | Answer | From |
|---|------|----------|--------|--------|------|
| Q1 | gate-machinery, F1 | Every switch off for a moment: every setting under it reads off by MasterOff, PageOn, PageSetting, Setting, StyleOn (real pages built) | forever | open | run 1 step 1 |
| Q2 | style-page-gate (C9) | Enable Style off: the ten Style page keys (questTalkStyled, selfTextStyle; not the finding's two values) read off by all | forever | open (offline PASS) | run 1 step 1 |
| Q3 | chat-bubbles-gate (C12) | Chat's Show or the HUD off: chatBubbles let go (yours back), the page's loop stops; on: held again | forever | open | run 1 step 2 |
| Q4 | chat-bubbles-gate | Speech from behind with Chat's Show off | forever | needs-state: someone talking behind you | - |
| Q5 | tooltips-gate (C13) | Mouseover's Show off: a real tooltip shows at alpha 1, no fade (on: fading in) | forever | open | run 1 step 2 |
| Q6 | gamepad-tabs (C7) | Show / Settings tabs off: bars not handled, press reveal off | forever | open | run 1 step 2 |
| Q7 | gamepad-tabs | The real GamepadMainActionBarFrame let go on a live flip | forever | needs-state: the gamepad UI in CineMode | - |
| Q8 | cdm-tab-gate (C8, D13) | Essential tab off: not centered, mode Always; page off: no ring / stacks loop | forever | open | run 1 step 2 |
| Q9 | cdm-tab-gate | Icons sliding back on a tab flip; Arcane Blast stacks with Bars on, Buffs off | forever | needs-state: a look at the bars, a mage | - |
| Q10 | hover-groups-page (E3) | Page off: groups and tooltips under it read off | forever | open | run 1 step 2 |
| Q11 | hover-groups-page | The Death Cam's kept groups with the page off; unit frame parts coming back | forever | needs-state: a death | - |
| Q12 | minimap-gate | Minimap's Show off: Questie's pins left to Questie | forever | open if Questie loaded, else needs-state: Questie | run 1 step 2 |
| Q13 | perf-gates (D5) | HUD off: the frame scan not wanted | forever | open | run 1 step 2 |
| Q14 | errors-alpha (E5) | Both hide boxes off: another addon's alpha on UIErrorsFrame kept; ticked hides, unticked ours back to 1 | forever | open | run 1 step 2 |
| Q15 | errors-alpha | The real error frame in a fight | forever | needs-state: a fight | - |
| Q16 | plates-names-tabs (C1) | Every Names tab off in CineMode: no names set of ours held (interactive NPCs apart, the card's call) | forever | open | run 1 step 3 |
| Q17 | plates-names-tabs | Enemy + Friendly off in CineMode: friendly plates' alphas as your own game settings show them (OwnKindShown); 2 shots | forever | open | run 1 step 3 |
| Q18 | plates-names-tabs | Plates' alphas in a fight, forced plates with your enemy plates off | forever | needs-state: a fight | - |
| Q19 | plate-parts-idle | Nameplates off: no plate parts loop | forever | open | run 1 step 3 |
| Q20 | chat-typing-tab (C6) | Conversations tab off in CineMode: opening the input box leaves the chat faded; on: up | forever | open (SKIP if your Chat row shows chat in CineMode) | run 1 step 3 |
| Q21 | style-* (D10, bbdd14f) | Enable Style off: no loop of Style's files, no game setting held for a Style page; 2 shots | forever | open | run 1 step 4 |
| Q22 | plate-theme-extras (C10) | Style off: a theme's shape and ground gone | forever | open | run 1 step 4 |
| Q23 | self-text-tabs (C3) | General tab off: the game's floating text let go | forever | open | run 1 step 4 |
| Q24 | combat-text-general-tab (C4) | General tab off: none of the game's number settings held | forever | open | run 1 step 4 |
| Q25 | combat-text-general-tab | The world text font at the next login with the tab off | forever | needs-state: a login with the tab off | - |
| Q26 | style-look-tabs (C2) | Bubble Style's Bubbles tab off: its look's default (also before the page is built: F3) | forever | open (offline PASS) | run 1 step 4 |
| Q27 | style-look-tabs | Bubbles redrawn live on the right-click | forever | needs-state: a bubble on screen | - |
| Q28 | raid-style-hooks (D2), style-page-watchers | Frames put back on the flip in a fight; Round glow's casts | forever | needs-state: a raid, a fight, casts | - |
| Q29 | style-hooks-rest, guild-line-name-style (C11) | Held plate lift, minimap ring copy; a titled plate's line redrawn | forever | needs-state: a look (shot run), a titled NPC | - |
| Q30 | letterbox-key-page (E1) | Page off: the key says so, no bars; on: bars on and off | forever | open (offline PASS) | run 1 step 5 |
| Q31 | letterbox-key-page | Ultra immersive with the page off | forever | needs-state: Chat Cam's Ultra immersive in a talk | - |
| Q32 | atmosphere-idle-cost (D15) | The view distance Preview: in, then back to yours, not held, its loop resting | forever | open | run 1 step 5 |
| Q33 | rain-view-page (C15), atmosphere-idle-cost | The view easing out as the Weather page goes off mid-rain | forever | needs-state: rain in CineMode | - |
| Q34 | death-song-page (E2) | Audio page off: no death song picked | forever | open (offline PASS) | run 1 step 5 |
| Q35 | death-song-page | Dying with the page off and music on | forever | needs-state: a death | - |
| Q36 | weather-suspend (C16) | Frost, lens rain, lightning after a safety stop / resume | forever | needs-state: rain or snow | - |
| Q37 | haze-loop-row (D14) | Visual Effects off: no haze / weather / view loop; Haze where its row says no | forever | open / needs-state: a camera mode in CineMode | run 1 step 5 |
| Q38 | graphics-plus-leave (B1) | Graphics+ after Later and a fight | forever | needs-state: a fight before the reload | - |
| Q39 | quest-talk-loops, quiet-loops, quest-cast-watch, sleep-bag-reads, emote-events-off | Every Vision off: no Quest Talk, item button, quest mob, bag, damage, roll, emote loop | forever | open | run 1 step 6 |
| Q40 | cards-boss-sounds (C19), cards-login-tabs (C20), vitals-wake (D18), emote-events-off, quest-cast-watch, quiet-loops, sleep-bag-reads, explore-index | Their live states | forever | needs-state: a boss, a login with tabs off, damage, a death, an item quest, a loot roll, the bag, a zone change | - |
| Q41 | cameras-your-triggers-off, cameras-off-scripts (D3), cameras-chat-cam-off, cameras-quest-cam-off, cameras-small-loops | Enable Cameras off: no trigger, script, zoom guard, Skyriding, Quest Cam, Chat Cam loop | forever | open | run 1 step 7 |
| Q42 | dev-mouse-turn-gate (C18) | Mouse Turn's tab off: no turn speed loop | forever | open | run 1 step 7 |
| Q43 | cameras-fishing-loop (D11) | Fishing page off with a pole on: no cast watch | forever | needs-state: a fishing pole on (read if one is) | run 1 step 7 |
| Q44 | cameras-* | Script keys/wheel (would move the camera: not asked), built-in trigger tabs, NPC talk, quest NPC, flight/death allow ticks, zoom fight, skyriding, trigger events, cozy tent | forever | needs-state: each named in the SKIP | - |
| Q45 | qol-refresh (C17) | Quality of life off: the XP bar's "(N left)" words gone | forever | open (SKIP at max level) | run 1 step 8 |
| Q46 | wheel-key-tab | The Wheels' key tab off: the menu wheel's cineoff set | forever | open | run 1 step 8 |
| Q47 | qol-campfire-loop (D1) | Cameras off, no sit button: no Campfire watch | forever | open | run 1 step 8 |
| Q48 | hunter-pull-loop (D4) | Hunter page off: no pull watch | classic era | needs-state: a Classic Era hunter | - |
| Q49 | panel-strips (D8), qol-refresh, qol-tickers | Drag strips with a window open; vendor Fill buttons; Reload key after a fight | forever | needs-state: a window, a vendor, a fight | - |
| Q50 | (all) | Every page and part switch off at once: no loop of the parts or the gated pages | forever | open | run 1 step 9 |
| Q51 | style-override-text (A1) | Style left out: Standard Frames and Nameplates open with no StyleOverrideText error | forever | open (offline PASS) | run 1 step 11 |
| Q52 | cameras-out-pages | Cameras left out: no Fishing page | forever | open (offline PASS) | run 1 step 11 |
| Q53 | toggle-effects-left-out | Atmosphere left out: the effects key says so, nothing changes | forever | open (offline PASS) | run 1 step 11 |
| Q54 | shoulder-leave (B2) | Load Cameras unticked: Shoulder Cam's held settings given back at the logout | forever | open if Shoulder Cam holds yours, else needs-state: Shoulder Cam on | run 1 step 11 |
| Q55 | (C21 finding) | Visions left out: the Why window's Cards tab made, no error | forever | open (offline PASS) | run 1 step 11 |
| Q56 | gate-tree-shape (F2) | The tree's switches the same with the parts left out | forever | **offline FAIL**: styleOverrides and visionsStyle lose their styleGeneral master (set in Style/StyleOverrides.lua:25, Style/VisionsStyle.lua:12, inside the Style part) | offline 2026-11-25 |
| Q57 | chat-history-page (B3) | Quality of life off for a login: chat history kept | forever | open if you keep chat history, else needs-state | run 1 step 11 |
| Q58 | time-title-test | /cine timetest with Visions out | forever | not in game: a dev command, offline-proven | card |
| Q59 | event-fact-* (9 cards), minimap-addon-buttons | Event facts and addon minimap buttons | both | out of this test: they need player actions (Rule Words / Event Facts kit tests, addontest) | cards |
| Q60 | (all) | The same on retail | retail | open: queue `--client both` when the user brings retail up | - |

## Plan tree
- Q56 FAIL in game too (expected: offline shows it) -> styleOverrides / visionsStyle put under styleGeneral in core (Core.lua's PAGE_SWITCH styleGeneral list), so they read off with Style left out. Next run: step 11 only.
- A loop listed as still running in steps 4-9 -> its file:line is in the verdict; read its wanted() and gate it, or allow-list it here with why (a loop that's on for a reason the switch doesn't cover).
- Q17 wrong alphas -> the plates' tab-off kinds (Effects.lua's tabOffKinds / OwnKindShown) against the shots.
- Q20 SKIP (your Chat row shows chat in CineMode) -> next run sets the chat row to hide in CineMode for the step.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| offline | 2026-11-25 | `python -I Tools/offline/run.py Tools/offline/gatingtest.lua forever` (and retail) | reaches DONE through the reload, 41 pass / 1 fail (Q56, real) / 51 skip, no Lua error in the test | game-only reads (alphas, attributes, loops' labels, plates) |
| 1 | 2026-11-25 | queue qd001, Forever, Lion's Pride Inn | 43 pass / 5 fail / 47 skip, 0 blocked. Real: CameraScripts.lua's watcher every frame with Enable Cameras off (fixed: 2026-11-25-script-watcher-loop.md); the target marks' When loop (PlateParts.lua) with Style / Smart off (fixed: 2026-11-25-target-marks-gate.md); PlateLayout.lua:743 in "every switch off" (another session's new Layout page: theirs). Test's own: E5 called ns.UpdateCVars inside its wait (all early returns), the letterbox key's verdict assumed bars off before the first press, the plate parts check didn't leave the Smart page's marks out: all three fixed | the 47 needs-state SKIPs (fights, rain, flights, NPCs, a vendor...); Questie's LibQuestieDB errors between queued tests (Questie's own load, not this test) |
| 2 | 2026-11-25 | queue q140e, Forever | 44 pass / 3 fail / 48 skip, 0 errors, 0 blocked; run 1's leaks gone (camera watcher, marks with Style off), E5, letterbox key passed. FAILs: the marks' loop's last pass inside the 1.5 s wait (their fade is 1.5 s, loops are asked once a second: test's, wait now 3 s); PlateLayout.lua:806 with Enable Style off (x8: its level-box duty is the Nameplates page's, by design: left out of the Style check with that page on) and in "every switch off" (x3: sent to the Layout session, theirs) | the needs-state SKIPs; the Layout loop with every switch off (its owner) |
| 3 | 2026-11-25 | queue q51d9, Forever | 45 pass / 2 fail / 48 skip, 0 errors in the test, 0 blocked. The Layout loop (11e50fe), the marks' tail, E5 and the letterbox key all passed. FAILs: Bubbles.lua:1062 x15 with the HUD off (Bubble Style's own watcher as people talked: the test now counts only the page's ticker, ~1015); PlateParts.lua:144 x341 with every switch off (the Plate parts keeper holding a part with the Nameplates page off: being found, card 2026-11-25-plate-keeper-page-off.md). Between tests: 8 "Error loading Style/Studio/Frames/*.lua" (the Style Studio session's files not on disk yet: theirs, expected) | the keeper's cause; the needs-state SKIPs |
| 4 | 2026-11-25 | queue q6bde, Forever, Elwynn Forest | 45 pass / 2 fail / 48 skip, 0 blocked. The Plate parts keeper: the new probe saw 0 parts held, "every switch off" passed (not seen again; the probe stays). FAILs: C6 typing raised the chat to 0.64 (a chat line's peek in Elwynn: the test now counts lines and tries again in a quiet second); CameraScripts.lua:3346 x24 with Enable Cameras off (the stopped-scene clear-out kept the loop wanted: dropped, card follow-up). Error: UI/Speech.lua:351 nil 'left' in step 2 (an old bug, ipairs over maybe-nil edges: fixed, Tools/offline/speechedges.lua, known.lua speech-edges-ipairs-nil) | the needs-state SKIPs |
| 5 | 2026-11-25 | queue qe20f, Forever, in town | 46 pass / 1 fail / 48 skip, 0 errors, 0 blocked; the plate parts probe 0 held again; C6 and the camera watcher passed. FAIL: QuestItemButton.lua:627 x66 with every Vision off (bag and quest events woke the button's loop with Quest Vision off: now only while it can show or still shows; quiet-loops card follow-up, its matrix's new itemEvent part) | the needs-state SKIPs |
| 6 | 2026-11-25 | queue qc81e, Forever, in town | 45 pass / 1 fail / 49 skip, 0 errors, 0 blocked; the quest item loop, plate parts probe (0 held) and everything before passed. FAIL: CameraScripts.lua:3348 x169 with Enable Cameras off, the whole sample: a script's raised zoom max held while the camera stayed out (checked every frame, so on for good): now checked in the loop's once-a-second wanted(), scriptwatchermatrix's new zoomedOut case; ns.CameraWatcherWhy logged as a probe | the needs-state SKIPs |
| 7 | 2026-11-25 | queue q3ad8, Forever, a town | 45 pass / 3 fail / 47 skip, 0 errors, 0 blocked; the camera watcher passed (probe: kept on by nothing). FAILs: PlateParts.lua:144 x168 / x341 (Nameplates off; every switch off): the probe answered run 3's question, 54 parts held at 0 on plates no longer up: the keeper's sweep now lets go of a part no shown plate has (card 2026-11-25-plate-orphan-parts.md); E5's ticked read stayed 0.5 again (passed runs 3-6: probe line added for why) | E5's cause; the needs-state SKIPs |
| 8 | 2026-11-25 | queue q64b6 stopped early twice (by hand, no fail); again as q0ccd, Forever, Elwynn | 47 pass / 1 fail / 47 skip, 0 errors, 0 blocked. Plate parts: probe 0 held, both plate loop checks passed (9f49a6f confirmed). Camera watcher passed. FAIL: E5 again, its probe: the pass ran, Out of combat's box ticked, nothing hidden: the pass reads In combat's box during the Calm Timer after a fight (ns.FightLingering), not logged then. The test now ticks both boxes and logs the Calm Timer | the needs-state SKIPs |
