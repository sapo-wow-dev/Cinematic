# Cooldown Manager grid: test ledger
Goal: the CDM page's spell icons as a grid: place groups across (any number of places + combat, or CQL), the bar's
row then its spells down, Otherwise last. A cell set (gold) or following (grey: a spell its bar's row). Click a cell:
its choices under the row (no dropdowns); right-click: back to following. A group's heading: its editor. Ticked rows:
set a column at once, copy/paste a row. Look: the old row settings as cells that step on click.
Code: UI/CooldownRules.lua (groups, cells, ns.CooldownRuleMode, ns.CooldownGroupTrouble), UI/CooldownGrid.lua (the
grid), Options.lua (CreateCooldownPanel: ListSpells, tabs), Frames.lua (ns.CooldownSpellMode / CooldownBuffMode order:
own cell, bar's cell, own Otherwise, bar's Otherwise), Migrations.lua (lines to groups, cooldownGridV1).
Tests: Tools/offline/cooldowngrid.lua (retail stand-in, prerelease), Dev/CdmGridTest.lua (/cine debug cdmgrid).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | A group's cell decides the icon (fade), bar's cell before the spell's own Otherwise | both | yes offline (ready pass) | cooldowngrid.lua |
| Q2 | Same in game: a cell Never fades the real icon; Anywhere first wins | forever | yes (target 0 / shown, dead group flagged) | run 1 steps 1-3 |
| Q3 | The grid fits the page (594 px), readable columns, the green dot, troubles | forever | yes (shot: fits, dot on the group in use) | run 1 step 4 |
| Q4 | Choices strip, group editor, ticked rows' bar, Look laid out right | forever | yes; Look's "Cooldown, not..." cut short: now "Own cooldown" | run 1 steps 5-8 |
| Q5 | Old lines become groups and cells | both | yes offline | cooldowngrid.lua |
| Q6 | Open CDM still opens the game's window and says Close CDM | forever | yes (window opens docked, Close CDM; again: shut) | run 2 step 9 |
| Q7 | Back from Look, nothing of Look left on the page | forever | yes after the fix (run 2 found "This bar:" left under the grid: `false ~= nil`) | run 3 step 8 |
| Q8 | The look fixed (the user, after f2540f5: "something doesn't look right", empty state): columns 120 max from the left, + Add a group column (wide with no groups) before Otherwise, bar's Otherwise gold, bar's row "Essential bar", no dot with no groups, Spell centered, ticks on hover only | forever | yes (offline, and in game: every one seen in the shots, with groups and none) | run 5 steps 4-8 |
| Q9 | The restyle (the user: "clunky, not stylish"; mockup frames D and E): a table, not boxes; pills with an icon and color per choice (Textures/CdmIcons, CdmDisc, Media/make_cdm_icons.py); the bar's gold band; tabs; + Add group pill, a card with no groups | forever | yes offline; open in game (new textures need a /reload) | run 7 steps 4-8 |

Proven: all 9 steps (run 8, full). Any step sets up its own test group (Setup) when the steps before are left out.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug cdmgrid | Q2, Q3, Q4: 11 PASS, 0 errors, 0 blocked, 5 shots right | Q6: test bug, `ns.CdmPageGrid and ns.CdmPageGrid()` kept only the grid, so no button (SKIP) and no shot backgrounds. Fixed |
| 2 | 2026-11-22 | /cine debug cdmgrid | Q6 yes; Q4's "Own cooldown" fits. 3 PASS, 0 errors | Q7 found in the step 9 shot (no step looked back after Look). Step 8 now checks and shoots it |
| 3 | 2026-11-22 | /cine debug cdmgrid | Q7 yes: 2 PASS, nothing of Look left (shot) | none |
| 4 | 2026-11-22 | /cine debug cdmgrid full | all: 14 PASS, 0 FAIL, 0 errors, 0 blocked, 7 shots right, settings put back | none: done in 4 runs (run 1's test bug cost one) |
| 5 | 2026-11-22 | /cine debug cdmgrid | Q8 yes: 9 PASS, 7 shots right | 1 FAIL the test's: "3 columns" counted step 3's group, left out (proven). Now 2 at least |
| 6 | 2026-11-22 | /cine debug cdmgrid full | all: 16 PASS, look fixes committed (d872f7d) | none |
| 7 | 2026-11-22 | /cine debug cdmgrid | Q9 mostly: 10 PASS, the pills, band, tabs, card and choices right in the shots | the no-groups shot ran past the panel (the test redrew with grid.Layout, no refit: now grid.Changed); Look's "This bar:" still boxes (now pills). The columns are "scenes" to players now ("group" read as party/raid; the user picked scene over situation, knowing cameras have Scenes too) |
| 8 | 2026-11-22 | /cine debug cdmgrid full | Q9 yes: 16 PASS, 0 errors; scenes, pills, the no-groups card fitting, Look's bar pills in the shots | none |
