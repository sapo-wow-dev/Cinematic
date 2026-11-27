# Death Vision: its Test follows Enable Visions (fix card)
Fix: with Visions > General's Enable Visions off (Death Vision's own page on), Death Vision's Test still showed
its screen, though its page reads off
Found by: audit 2026-11-25 (review of the Vitals wake fix, 2026-11-25-vitals-settle.md)
Code: Atmosphere/DeathVision.lua: UpdateDeathScreen (the Test's condition)
Clients: both
Base: cc7e40d

## Before / after
- Before: the Test went by the page's raw switch (db.deathScreen), so with Enable Visions off it still ran.
- After: by ns.PageSetting("deathScreen"): page off, by its own switch or a master over it (Enable Visions,
  Visions left out), no Test. Allow outside CineMode isn't asked (the Test is started from its page, out of
  CineMode), as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs deathVisionTest TestDeathVision deathScreen`)
- Players: only someone pressing Death Vision's Test with Enable Visions off: it now does nothing, as every
  other Vision's.
- Other features: the death camera's screen itself (want) already used ns.Setting("deathScreen"): unchanged.
- Other addons: none.
- Tests that encode it: deathoutsidematrix.lua (ns.Setting by Allow outside CineMode): unchanged.

## States (the matrix)
Death Vision's page on or off, Enable Visions on or off, its Test running or not (alive).
Test: Tools/offline/deathtestmatrix.lua forever
Test: Tools/offline/deathtestmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| death-vision-test | page=on visions=off test=running | shows | none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one condition. Not proven offline: the page's Test button greying with Enable Visions off (the page
greys by ns.PageSetting already).
