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

| Q10 | Round 3 (the user: "mouseover sucks", "clicking a row sucks", "multiple scenes looks really bad"): pills light under the pointer, no tooltips but for icons alone; the name no longer ticks; choices in a pop-up under the cell (nothing moves; a pick or a click away shuts it); new scenes named "Scene N"; 4-5 scenes: icons alone, places under names hidden; one line for scenes with no places; + Add scene by the tabs; editor and ticked-rows bar as pills | forever | yes offline; open in game: the gallery step shoots every setup | run 9 |

| Q11 | The neutral look (the user: "this looks so bad", "annoyed at the gold"; mockup F-H): gold only on the game's own title and tab; greys and white for what we add; color only for the choices; following cells blank (their faint icon under the pointer); the bar's row a lighter row; places in the headings' tooltips, amber "pick places" / "never applies" only; the editor a plain panel, picked chips filled light | forever | yes offline; open in game | run 12 gallery |

| Q12 | No Cities or Inns chips (the user: "who cares about combat in cities and inns"); shown only on a scene that has them; one off Anywhere = the other chips' places; a note points to Rule... | forever | yes (both cases in the shots) | run 14 |

| Q13 | A bar's tab warns (amber "!", tooltip naming each) when a cell on it never takes effect (its scene never applies or has no places) | forever | yes ("Essential !" in the shot, its line right) | run 15 gallery |

| Q14 | No scenes: the last column headed "Shows", not "Otherwise" (the user); a tab's "!" left over after a test put settings back with the page open: now recalculated on every page refresh | forever | yes offline; open in game | run 17 gallery |

| Q15 | The bar's row reads as the spells' parent (the user: "looks kind of like the other rows"): tried a tree (indent, line): no. Now mockup J: the bar on a raised card of its own, room around it, a SPELLS label over the spells | forever | yes offline; open in game | run 17 gallery |

Proven: all but the gallery. Any step sets up its own test group (Setup) when the steps before are left out.

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
| 9 | 2026-11-22 | /cine debug cdmgrid | Q10 mostly: 12 PASS, 0 errors, 12 gallery shots looked at | from the shots: following cells' faint words buried the set ones (now icon alone); Otherwise's dot floated at the far edge (now after the name); five scenes cut names (now two lines); hover too faint (stronger); Look hint cut (shorter). No tracked buffs: buffs bar not shot |
| 10 | 2026-11-22 | /cine debug cdmgrid | Q10 yes: the gallery again, every fix seen (icons alone for following cells, dot by the name, two-line names at five, hover, Look hint) | the buffs bar (no tracked buffs here) |
| 11 | 2026-11-22 | /cine debug cdmgrid full | all: 18 PASS, 0 errors, settings put back; committed | none |
| 12 | 2026-11-22 | /cine debug cdmgrid | Q11 mostly: 6 PASS, 0 errors, 12 shots: the neutral look reads well | from the shots: the bar row's "every spell follows this row" ran under the first cell (now "for every spell", kept in its column); "never applies" sat on a wrapped name at five scenes (one line when there's a note); Look's hint still said Gold (reworded) |
| 13 | 2026-11-22 | /cine debug cdmgrid | Q11 yes: 6 PASS, 0 errors; "for every spell" in its column, one-line names with notes, Look's hint right | none (a mob pulled near the end; no effect) |
| 14 | 2026-11-22 | /cine debug cdmgrid full | Q11, Q12 yes: 18 PASS, 0 errors; no town chips with the Rule note, Town keeps its chips lit; committed | none |
| 15 | 2026-11-22 | /cine debug cdmgrid | Q13 yes: 3 PASS, 0 errors | none |
| 16 | 2026-11-22 | /cine debug cdmgrid full | all: 19 PASS, 0 errors; committed | none |
| 17 | 2026-11-22 | /cine debug cdmgrid | Q14 yes ("Shows", no stale "!"); the card in; 3 PASS | the user: "lot of visual issues". From the shots: a double rule (heading line + card top) with a gap; SPELLS pressed against the card and first row; tall empty heading row. Fixed spacing |
| 18 | 2026-11-22 | /cine debug cdmgrid | (pending) the user kept finding look issues: every run-17 shot read up close (crops), fixed: gold "2 ticked", "Same as bar" not a chip, bar icon out of line with the spells, five-scene notes cut short; with the user's: no SPELLS, no cities note, Delete too wide. The gallery now audits each shot (cut-short text, gold, overlapping buttons) | audit all PASS; up close: pop-up title cut (audit missed it: now also width vs room), pop-up see-through, Show early box tall. Fixed |
| 19 | 2026-11-22 | /cine debug cdmgrid | 12 PASS, audit clean | the user's shot: Scene 1 editor (never in the gallery): "pick places" twice, black name box |
| lab | 2026-11-22 | CDM lab (Tools/style-lab, --cdm), 13 states, no game | found and fixed offline: headings 10 px over the bar's cells (clicks), "Scene 1"/"pick places" on each other (from that fix), the in-use dot against the next heading when a name wraps, Buffs bar "for every spell", Copy row bare text; plus the user's two. Lab fixed too: frame levels drew the card over the bar row | |
| 20 | 2026-11-22 | /cine debug cdmgrid | the lab's fixes confirmed: 16 PASS, audit clean, the game matches the lab; committed | none |
| lab | 2026-11-22 | CDM lab | no-scenes card dropped for the small + Add scene (the user: the bar unneeded, its button text looked off); hint without scenes "Blank: same as the bar." Lab audit clean, looked at | |
| 21 | 2026-11-22 | /cine debug cdmgrid | 16 PASS, audit clean; no card | the user still saw issues; up close: pop-up title cut ("Dungeon" lost "fights": measured before its width was set), the game's checkboxes and edit box in the pop-up (the lab can't draw game art, so it missed them). Now: pop-up wider, title width set first, toggle chips, a soft field. Lab looked at |
| 22 | 2026-11-22 | /cine debug cdmgrid | 16 PASS, 0 errors: the pop-up chips, field and title, no card | the user: the hint line has no point. Removed (lab looked at) |
