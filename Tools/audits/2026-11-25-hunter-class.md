# Hunter: the right-click pull never on another class (fix card)
Fix: on Classic Era, a non-hunter with the Hunter page on lost right-click on enemies in fights (and right-drag turning over an enemy) after the page's switch or any profile switch/Reset, till /reload
Found by: audit 2026-11-25 (review of 6e67ddd's new callers)
Code: QoL/Hunter.lua: Wanted (IsHunter, new), ns.RefreshHunterPull, the PLAYER_LOGIN class check; the comment above the watch (the setting is on by default, the page off)
Clients: Classic Era only (the file returns on every other client)
Base: cc7e40d

## Before / after
- Before: a warrior (any class but hunter) on Classic Era with the Hunter page on: clicking the page's switch,
  or switching profile or Reset, ran ns.RefreshHunterPull, which registered the fight's state driver
  (Right click attack also uses Auto-shot is on by default). In a fight, the mouse on a living enemy bound
  right-click to the pull button, which has no macro on a non-hunter (set only at a hunter's login):
  right-click on an enemy did nothing, and a right-drag started over one didn't turn the camera, till /reload.
- After: on a non-hunter nothing in Hunter.lua binds or drives anything, whatever the setting, page or
  profile. A hunter: exactly as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshHunterPull hunterRightClickShot CinematicHunterPullButton ApplyDriver`, every hit read.)
- Players: hunters (unchanged: IsHunter is true for them, same driver, binding, watch and macro). Non-hunters:
  none want it; it only ever broke their right-click.
- Other features: Options.lua:10323 (the Hunter page switch) and Profiles/Profiles.lua:523 (SettingsChanged)
  call ns.RefreshHunterPull; for a non-hunter it now returns at once. QoL/HunterAmmo.lua's own class check
  untouched.
- Other addons: none.
- Tests that encode it: hunterpullmatrix.lua (a hunter: unchanged, kept as a Test here), qolrefreshmatrix.lua
  (the refresh is called; it doesn't load Classic Era). Cards 2026-11-25-hunter-pull-loop.md and
  2026-11-25-qol-refresh.md (hunters only; their cells unchanged).

## States (the matrix)
The class (hunter, warrior: one run each, the class is read at login), the Hunter page on/off, the tick on/off,
reached from the page's switch (ns.RefreshHunterPull) or a profile (ns.SettingsChanged), the mouse on a living
enemy or nothing, out of a fight. Outcome: the fight's state driver registered, right-click bound to the pull
button now, the every-frame watch running, the pull button's macro set.
Test: Tools/offline/hunterclassmatrix.lua hunter
Test: Tools/offline/hunterclassmatrix.lua warrior
Test: Tools/offline/hunterpullmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| hunter-class-warrior | class=warrior page=on tick=on | driver=on bind=none loop=off macro=none | driver=off bind=none loop=off macro=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one class check on what already only hunters were meant to have; hunters' cells unchanged (hunter-class-hunter
16 cells, hunter-pull-loop 8; hunter-class-warrior's other 12 too). The class is read once, the first time the game gives it (at login or the
first refresh). Not proven offline: the real fight binding in game (the state driver and secure handler are
stand-ins here), and right-click/right-drag on an enemy in a fight on a Classic Era non-hunter.
Already broken players get it back at their next /reload (nothing was saved).
