# Control looks: test ledger
Goal: a screenshot of every unique menu control as it really looks, in HD and SD, to pick one look per kind
(Tools/ui/control-map.md).
Code: Dev/ControlGallery.lua, Dev/ControlLooksTest.lua (/cine debug controllooks), Style/PageShots.lua (reused)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does each gallery builder make its control in game (29 rows)? | both | open (offline: 29/29 on both) | run 1 steps 1, 5 |
| Q2 | Do the menus open from code (DropdownButton:OpenMenu, C.Drop click, TickMenu, ContextMenu)? | both | open (offline: 6/6) | run 1 steps 2, 6 |
| Q3 | Does each window open from code and show as one new UIParent child to shoot and hide? | both | open (offline: Studio, Why, Find, Rule editor, Welcome yes; color picker and talent calc need the game) | run 1 steps 3, 7 |
| Q4 | Does each page word find its page for ns.PageShots? | both | open (offline, PageShots stubbed) | run 1 steps 4, 8 |
| Q5 | Does the SD look really apply to every page after CinematicDB.menuSkin + ApplyMenuSkin(true)? | both | open | run 1 shots |
| Q6 | Is the menu look put back after the run (and after a stop or a /reload mid-run)? | both | offline yes (putBack) | run 1 put back line |

## Plan tree
Q1-Q4 yes: the shots are the deliverable; nothing to build. A row FAIL: fix that gallery row (its builder's
arguments), not the builder. A window with 0 new frames: it parents elsewhere; shoot it with `behind` set to its
named frame instead. A page word that finds 0 pages: use the page's English key from ns.SettingsPages().

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
