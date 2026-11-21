# Load Visions: test ledger
Goal: unticking Visions General's Load Visions keeps every Vision's code from running after a reload (Visions/, Vitals, Death, Teleport, Wind Guide: no frames, hooks, loops) and every place they show gone (pages, Style pages, wheel, Welcome, keybind rows), the rest of the addon works, the Vision settings stay, and ticking it brings it all back. User rule 2026-11-21: all Visions, front end and back end.
Code: Modules.lua, Atmosphere/DeathVision.lua (out of Tint.lua), Atmosphere/LowHealth*.lua, VitalsSound.lua, TeleportVision.lua, Profiles/Welcome.lua + ShowMe.lua, QoL/WheelsPage.lua, Locales/Locales.lua (ns.RunModules first at ADDON_LOADED), Visions/*.lua (ns.Module), Core.lua (LEFT_OUT switches), Options.lua (box, gated pages), Style/StyleFonts.lua, QoL/MarkerWheel.lua, UI/WhyFeatures.lua, Slash.lua, Dev/LoadVisionsTest.lua

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Locales.lua's ADDON_LOADED handler (which runs the Visions code) fires before Core.lua's, so Visions runs before ns.db and the language? | forever | YES: db=false, locale enUS, saved settings there | run 1 step 2; rule addon.addon-loaded.handlers-in-register-order |
| Q2 | Combat state for code run at ADDON_LOADED same as at file load? | all | YES: ADDON_LOADED is SynchronousEvent, fired straight after the addon's files | Tools/engine/api forever apidocs (known.py) |
| Q3 | Secure buttons made at ADDON_LOADED instead of file load (CinematicQuestItemButton, CinematicQuestTalkClearTarget with SetAttribute) made and protected, no BLOCKED? | forever | YES: both protected (type item, macro), 0 blocked | run 1 step 2; rule addon.secure-buttons-made-at-addon-loaded |
| Q4 | Real Load Visions box + its Reload popup (cineReload cover) on Forever: reloads by one click? | forever | YES (run 3). Run 1-2: the popup was found (StaticPopup_FindVisible) but on neither screenshot, its .text nil, and the user clicked the kit's Reload (2nd "reload clicked" line); run 2 logs its state and asks; reload from addon code blocked is tested (forever.reloadui.blocked), the covered popup is QoL/Reload.lua's tested way | run 1 steps 2, 4 |
| Q5 | Visions off: none of its frames, no errors while playing (plates ask the stand-ins), memory lower by how much? | forever | YES no Vision code, 0 errors, 2795 frames fewer; memory: open (run 1 without a garbage collect: 94 MB on, 69 off, 71 back on fresh) | run 1 step 4; run 2 collects first |
| Q6 | Settings kept through off and back on (a changed Vision setting, profile, the defaults copy cleared once loaded)? | forever | YES (kept off, in the profile, back on, copy cleared); run 1's one FAIL: a copy while on, left by unticking then ticking before a reload: fixed (ticking on while loaded drops it) | run 1 steps 2, 4, 5 |
| Q7 | Back on: everything as before (frames, pages, wheel)? | forever | YES | run 1 step 5 |

Widen the net: states: out of combat only (the gate runs at load; Q2 settles combat). Secrets: none read. Protection: kit counts deverror/BLOCKED per step; Settings not opened (memory settings-open-gamepad-blocked-line: opening it from code can log a blocked line). Clients: Forever (retail later if the user asks). Cinematic's state: CineMode off (kit), a changed Vision setting carried. Other addons: none touch the gate. What the user sees: the Reload popups (shots). Cost: memory with and without.

## Plan tree (step 3)
Q1 no (Core first) -> ns.RunModules from Core's handler before ns.db too; DEFAULTS still right (both run before the defaults loop): log enough (moduleStart) to move it without another run.
Q3 blocked -> those two buttons made lazily out of a fight; the log's BLOCKED stack names which.
Q4 popup Later / not covered -> the step's own kit Reload button as the fallback, same run.
Q5 an error -> the step's deverror lines name the call; fix with a stand-in or guard, the confirm run.
Q6/Q7 lost -> the log shows which key / page.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug loadvisions | Q1 Q3 Q6 Q7, Q5 but memory; 35 PASS 1 FAIL (the test's too-strict start; fixed in code) | Q4: the Reload box wasn't seen and the log had no state for it (test's fault: fixed, run 2 logs it and asks); memory: no garbage collect |
| 2 | 2026-11-21 | /cine debug loadvisions | memory: 61.3 MB on, 47.7 off, 61.2 back (13.6 MB saved, garbage collected first); Q4 half: the Reload box is made, shown, visible, alpha 1, DIALOG, 320x74, at the game's spot (135 under the top), the cover on it; 38 PASS 3 FAIL (you couldn't see it x3) | Q4's click: the test's own box (FULLSCREEN_DIALOG, TOP -120) sat right over the game's popups and hid them (the kit's fault, every test with a popup). Fixed: Frames.lua ns.PadTestBox steps under any shown StaticPopup (offline check in loadvisions.lua) |
| 3 | 2026-11-21 | /cine debug loadvisions (confirm) | Q4 YES: the test's box now under the game's Reload box (screenshots WoWScrnShot_112126_1522*/1523*), you saw it x3 and its own Reload (the Forever cover) reloaded each time (no kit Reload line); 39 PASS 0 FAIL, 0 errors, 0 blocked; memory again 61.7 on, 48.1 off (13.6 MB), 61.4 back | none |

Offline before run 1: every step PASS on the stand-in, through the reloads (3 loads started on, 4 started off). The stand-in hands back a stub for any unknown global, so the test reads frames with rawget(_G, name).
User actions: a Reload click per reload (2, or 3 starting with Visions left out): the reload is what's tested, and Forever blocks reloads from our code (forever.reloadui.blocked).

Done: every question answered in 3 runs (the budget). Run 2's surprise was the kit's own box over the game's popups (Frames.lua ns.PadTestBox now steps under them, for every test).
