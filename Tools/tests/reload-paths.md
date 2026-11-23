# Reload paths: test ledger
Goal: every reload a player starts from Cinematic (Reload button, Reload key, popups that reload) reloads on Forever, where ReloadUI from addon code is blocked; retail unchanged.
Code: QoL/Reload.lua (ns.Reload, cineReload popup cover, CinematicReloadKey override, secure Reload button), Core.lua / Options.lua / Profiles/*.lua popups, Dev/AddonTest.lua solo.
Tests: Tools/offline/reload.lua (both clients, prerelease), Dev/ReloadPathsTest.lua (/cine debug reloadpaths [full]).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | ReloadUI from a timer blocked? | forever | YES, blocked | run 1 step 1; rule forever.reload.addon-code-blocked |
| Q2 | Popup with OnAccept = ReloadUI blocked? | forever | NO, reloads | run 1 step 2 |
| Q3 | Secure Reload button (LeftButtonUp, useOnKeyDown false) reloads? | forever | yes | run 1 step 3 |
| Q4 | Override binding click on the secure key button reloads? | forever | yes (SHIFT-/, ActionButtonUseKeyDown on) | run 1 step 4 |
| Q5 | Cover over a popup's button 1 / button 3 runs its work, then reloads? | forever | yes (language, turn off, reset button 3, ask) | run 1 steps 5-8 |
| Q6 | Popup OnAccept as a Lua closure calling ReloadUI: blocked? | forever | open, not needed (covers work) | - |
| Q7 | All paths on retail | retail | open; offline says ReloadUI as before | Tools/offline/reload.lua |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug reloadpaths | Q1-Q5: 7 pass, 0 fail | Q6 not probed (not needed); Q7 retail not run. The prompt box hid the popups' buttons: TestPrompt now goes below any open popup. All Forever steps marked proven. |
