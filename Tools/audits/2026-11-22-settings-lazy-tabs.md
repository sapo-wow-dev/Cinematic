# Settings: a tab switched off is off from login; Graphics+'s tabs (fix card, retroactive)
Fix: since pages are made on first open, a setting hung under its tab (and the tab under its page) only once its page
was built, so after a login or /reload a tab (or page) switched off read on until the page was opened; Graphics+ read
each tick on its own, never its tab, and a tab's flip wrote nothing.
Found by: audit 2026-11-22; fixed in 7c3e0c1
Code: LazyPageDefaults.lua (ns.LAZY_PAGE_SWITCHES), Options.lua: ns.TabContainer (ns.tabSwitchHooks), Graphics.lua: ns.ApplyGraphicsPlus
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: Nameplates' Enemy tab switched off (or the whole Nameplates page off): enemy plates kept our parts after a
  login until the Nameplates page was opened. Graphics+'s Sky and water tab off: the sky setting stayed ours; a
  right-click on the tab changed nothing until another Graphics+ setting moved.
- After: off from login, page opened or not; Graphics+'s tabs let the game's own setting back, and a tab's flip writes
  it at once.

## Who relies on the old behavior
(`python -I Tools/audit.py refs plateOwnPartsEnemies updateNotice ApplyGraphicsPlus TabContainer LAZY_PAGE_SWITCHES`;
it crashes on a non-cp1252 hit on Windows: set PYTHONIOENCODING=utf-8.)
- Players: anyone with a Nameplates tab, the Nameplates page or a Graphics+ tab off (default all on), who logged in and
  played without opening that page: their switch now counts from login.
- Other features: ns.Setting walks the tree (Core.lua); Effects.lua and Graphics.lua call ns.ApplyGraphicsPlus;
  Dev/Sweep.lua runs ns.MapTabContainers. WhatsNew.lua reads db.updateNotice / db.handleChat raw (see Found next to it).
- Other addons: none.
- Tests that encode it: Tools/offline/lazytabs.lua (kept), lazyaudit.lua (writes the links), memory tab-is-container.

## States (the matrix)
page made yet (no / yes) x the setting's page (Nameplates Enemy tab, Graphics+ Sky and water tab, Chat Updates tab)
x the page's switch x the tab's switch x how the tab got its state (saved at login / flipped on the page, only once
made), per client. 48 cells.
Test: Tools/offline/lazytabsmatrix.lua forever
Test: Tools/offline/lazytabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| lazytabs-switch | made=no page=plates how=saved pageSwitch=on tab=off | on | off |
| lazytabs-switch | made=no page=plates how=saved pageSwitch=off | on | off |
| lazytabs-switch | page=gfx pageSwitch=on tab=off | ours | game |

## Found next to it
- **The Chat page's Updates tab does nothing** (before and after this fix, both clients): with the tab switched off the
  What's new line still shows at login. WhatsNew.lua's login check reads `db.updateNotice` and `db.handleChat` raw,
  not ns.Setting, so the tab (and the Interface hub above the page) aren't read. The 3 cells
  `page=chat pageSwitch=on tab=off` FAIL on every version. Not fixed here (report only).

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card; lazytabs.lua kept) | | | | |

## Risk
low: retroactive. Not proven offline: the page build's real timer (MapTabContainers is called by hand), the in-game
right-click on a tab.

## Open (user's call)
- `page=chat pageSwitch=on tab=off`: pinned "off" (the switch tree: a tab off = its settings off). The other reading,
  "the Updates tab is only a grouping", contradicts tab-is-container; pinned off.
- `made=no how=flipped`: pinned "n/a" (no tab to right-click before the page is made).
