# Keybinds: the Wheels tab off stops the wheels' keys (fix card)
Fix: with the Keybinds page's Wheels tab switched off, the wheels' keys still opened their wheels (their keys click secure buttons, which Bindings.xml can't ask)
Found by: audit 2026-11-25 (gating, finding E4; decided: a tab off = everything on it off)
Code: QoL/MarkerWheel.lua: WheelKeyOn (new), ns.ApplyWheelSwitches, the PLAYER_ENTERING_WORLD watcher (registers ns.tabSwitchHooks["tabOn:Keybinds:"])
Clients: both
Base: baabf86

## Before / after
- Before: Keybinds > Wheels tab off: the Master, Menu, Marker, Ground marker and Vision wheel keys still
  opened their wheels (the tab's other keys did stop).
- After: with the tab off those keys do nothing (each wheel's "cineoff", as its Wheels page off does), at
  once out of a fight, after it in one. On again: they open again. Custom wheels' keys (bound on the Wheels
  page, on no Keybinds tab) are unchanged.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ApplyWheelSwitches cineoff Cinematic_KeyOn tabSwitchHooks`)
- Players: those with the Wheels tab off: the tab's own words say its keys do nothing.
- Other features: the master wheel opening a wheel (OPEN_SNIPPET reads cineoff): its key is on the same
  tab, so it's off too. Profiles (SettingsChanged already runs ApplyWheelSwitches), Dev/KeybindSwitchTest.lua
  and Dev/ProfilePartsTest.lua (cineoff with the page off: unchanged).
- Other addons: none.
- Tests that encode it: none offline.

## States (the matrix)
The wheel (Marker, Menu), its Wheels page on or off, the Keybinds Wheels tab on or off (its switch clicked).
Test: Tools/offline/wheelkeytabmatrix.lua forever
Test: Tools/offline/wheelkeytabmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| wheel-key-tab | page=on tab=off | key=opens | key=nothing |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more condition on an attribute the wheels already obey. Not proven offline: a real key press on
the secure buttons, and the tab flipped in a fight (applied after it, as the page switches are). Still
not stopped by the tab (not wheels, out of this fix): the quest item key (CinematicQuestItemButton) and the
target-the-speaker key (CinematicChatTargetButton), both secure. The shoulder-swap key is a plain Lua button
on no Keybinds tab (bound on the Shoulder Cam page), so no tab governs it.
