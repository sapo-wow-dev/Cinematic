# Load Cameras: test ledger
Goal: unticking Camera > General's Load Cameras keeps every camera's code from running after a reload (Camera/: the cameras, scenes, triggers, scripts, shots, Shoulder and Skyriding Cam, Chat and Quest Cam) and every place they show gone (pages, keybind rows, the camera wheel, Welcome demos, the Why tab's rows), the rest of the addon works, their settings stay, and ticking it brings it all back. Same rule as Visions (user, 2026-11-21): all of it, front end and back end.
Code: Modules.lua (cameras part, stand-ins, key stand-ins), Camera/*.lua (ns.Module "cameras"), UI/ShareWindow.lua (out of CameraTriggerEditor.lua: Style Themes and Vitals share through it), Core.lua (LEFT_OUT camera switches, StartCam/StopCamera, flight CVar sets), Options.lua (ns.LoadPartBox, Cameras page, Camera Settings, keybind rows and stable tab numbers), Migrations.lua, Profiles/ProfileModules.lua, Profiles/Welcome.lua + ShowMe.lua, QoL/MarkerWheel.lua (camera wheel key wrap) + WheelsPage.lua, UI/WhyFeatures.lua, Slash.lua, Dev/LoadPartsTest.lua (was LoadVisionsTest.lua).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Code run at ADDON_LOADED instead of file load, secure buttons made then | forever | YES (Visions' runs: rules addon.addon-loaded.handlers-in-register-order, addon.secure-buttons-made-at-addon-loaded) | Tools/tests/load-visions.md |
| Q2 | Camera code's secure buttons (CinematicShoulderEscapeButton, ...) made and protected when its code runs at ADDON_LOADED? | forever | YES: CinematicShoulderEscapeButton protected type macro, 0 blocked | run 1 step 2 |
| Q3 | Cameras off: none of their code, 0 errors in play (CineMode, flights, death, movement go through stand-ins), memory saved? | forever | YES: none of their frames, 0 errors in 8 s of play; with Visions off too: 20.9 MB less, 4,100 frames fewer | run 1 step 4 |
| Q4 | Their keys (camera wheel, AFK camera) and commands (/cine flyby) say Cameras aren't loaded? | forever | YES (flyby, AFK key, camera wheel key) | run 1 step 4 |
| Q5 | Settings kept off and back (walkCine, in the profile; Keybinds tab switches on their own tabs)? | forever | YES (walkCine kept, in the profile, back) | run 1 steps 4, 5 |
| Q6 | Both parts off together, then back: everything as before? | forever | YES | run 1 step 5 |

Widen the net: states: out of combat (Q1 settles combat at load). Protection: the kit counts deverror/BLOCKED per step. Clients: Forever. CineMode: kit keeps it off; with Cameras off nothing should start one. What the user sees: the Reload boxes (shots), the test box under them (kit fix).

## Plan tree (step 3)
Q3 an error -> the step's deverror line names the call: a stand-in or guard, the confirm run.
Q2 blocked -> those buttons made lazily out of a fight.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug loadparts | Q2-Q6: 55 PASS 0 FAIL, 0 errors, 0 blocked | none; but two Reload boxes (one a part): the user wants one. Fixed: one popup naming every change (Options.lua ns.LoadPartBox) |
| 2 | 2026-11-22 | /cine debug loadparts (confirm) | the one Reload box YES (x3, naming both changes, its own Reload used); 57 PASS 0 FAIL, 0 errors, 0 blocked; both off 19.3 MB less | none. The box said "step 4/2" after a reload: the kit counted the steps left, now all of them (Dev/TestKit.lua; loadparts.lua checks it) |

Done: every question answered in 2 runs.

| 3 | 2026-11-22 | /cine debug loadparts (after Camera > General showed "General is off" over its box: the tests only checked the box existed) | Camera > General in the menu: no off card, Load Cameras box shown (WoWScrnShot_112226_011212); 76 PASS 0 FAIL, 0 errors | none. The test's box covered the page's top in its menu shots: hidden for them now |
