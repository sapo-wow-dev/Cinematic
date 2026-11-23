# Other addons: DaylightUI and Leatrix Plus layouts (fix card)
Fix: DaylightUI's layout keeper replaced one set before it (Leatrix Plus's) instead of asking it, so with DaylightUI loading after Leatrix Plus, Leatrix Plus's layout and a profile's took turns at every login.
Found by: audit 2026-11-22 (retroactive card, 2026-11-23)
Code: Support/DaylightUI.lua: its ns.layoutKeeper; Support/LeatrixPlus.lua: its keeper; Profiles/Layouts.lua: KeptBy(), LeftToKeeper()
Clients: both
Base: bdb2e1d^

## Before / after
- Before: with both addons in, DaylightUI's ADDON_LOADED after Leatrix Plus's (DaylightUI loaded late, or the
  setups' order at login), and DaylightUI keeping no layout of its own: a profile's layout switched Leatrix Plus's
  away and Leatrix Plus put it back, each login asking for a reload.
- After: DaylightUI's keeper asks the one before it; either order gives the same keeper.

## Who relies on the old behavior
(`python -I Tools/audit.py refs layoutKeeper editModeLayout`)
- Players: built-in profiles with a layout (Cinema, Shoulder Cam, Follow HUD...) with DaylightUI and/or Leatrix Plus.
- Other features: Profiles/Layouts.lua's ApplyProfileLayout (left to the keeper), Profiles/FollowHud.lua.
- Other addons: Support/DaylightUI.lua, Support/LeatrixPlus.lua (already chained before this fix).
- Tests that encode it: Tools/offline/questiegate.lua check 3.

## States (the matrix)
Which addons are in and how (none / DaylightUI at login / Leatrix Plus at login / both loaded after login in either
order / both with one's support off) x DaylightUI keeping a layout (yes / no / its Edit Mode part not made) x Leatrix
Plus keeping one (Set edit mode layout ticked with a name: yes / no), per client.
Test: Tools/offline/layoutkeepermatrix.lua forever
Test: Tools/offline/layoutkeepermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| layout-keeper | loads=lea>dui duiLayout=no leaLayout=yes | keeper=none | keeper=Leatrix Plus |
| layout-keeper | loads=lea>dui duiLayout=unmade leaLayout=yes | keeper=none | keeper=Leatrix Plus |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: one keeper chained. Not covered: both in at login (the setups run in pairs() order: either order, both in the
matrix); a profile's layout actually switching (the matrix reads the keeper ApplyProfileLayout asks).
