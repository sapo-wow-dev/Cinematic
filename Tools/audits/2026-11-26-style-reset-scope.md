# Style editor: Reset's widest scope on a page is the page (fix card)
Fix: on a Style page with the editor, Reset > "Everything in Style" reset every Style frame, other pages' looks too
Found by: audit 2026-11-26
Code: Style/Studio/Studio.lua: Host:ResetMenu, ns.StyleEditorPage (host.pageScope)
Clients: both
Base: 679e735

## Before / after
- Before: on Name Style, Nameplate Style, Nameplate Layout, Cast bars or Range Hint's page, Reset offered
  "This part", "This variant", "This frame" and "Everything in Style (N)". The last reset every Style frame:
  Tooltips, Minimap, Interface Recolor, Combat Text, Text on You, General's theme picks, Quest Talk (its spot
  too), Quest Item, Roll, Card Types, unit and raid frames. One pick on the Names page wiped them.
- After: on a page, Reset offers "This part", "This variant" (where the page has several and shows them) and
  "Everything on this page (N)": what the page's editor shows, every variant of its frame (Nameplate Style's
  Default and every row; Layout's every kind), Cast bars only its own Plates variant, the same as the page's
  Reset page. Its count and confirm as before. Nothing on another page changes. "This frame" is folded into it
  (on a page it was the same thing). The Studio window (no player can open it) keeps This frame and
  Everything in Style.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ResetMenu ResetWrites`, read every hit.)
- Players: a player who used "Everything in Style" from a page to start their whole Style over; now it's the
  page only (the Style hub's Reset and each page's Reset page are unchanged).
- Other features: Studio.ResetWrites / Studio.Reset unchanged ("all" still there for the window); Looks'
  Theme's look uses "variant"; each page's Reset page (kit.OnReset) unchanged.
- Other addons: none.
- Tests that encode it: Tools/offline/styleresetownmatrix.lua calls Studio.ResetWrites("all") / Studio.Reset("all")
  directly (unchanged); Tools/offline/stylestudio.lua opens the window's ResetMenu (unchanged);
  Dev/StyleStudioTest.lua presses a page's Reset twice (opens/closes: unchanged). Nameplate Style, Layout and
  Cast bars hide Reset today (f.pickers / opts.pickers): the menu is reachable on Name Style and Range Hint's page.

## States (the matrix)
The host (a page's editor built with its page's options, or the Studio window), its frame (names, range,
plates, platelayout, cast), and the one setting of yours (on the page's variant, on another variant of the
frame, on Tooltips, on another editor page's frame), the client. Each cell: the rows, the widest row's words,
whether it counted the setting, the setting after picking it and Yes.
Test: Tools/offline/styleresetscopematrix.lua forever
Test: Tools/offline/styleresetscopematrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-reset-scope | host=page frame=names yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=names yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=names yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=names yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=plates yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=plates yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=plates yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=plates yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=platelayout yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=platelayout yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=platelayout yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=platelayout yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=cast yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=cast yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=cast yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=cast yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=range yours=here | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope | host=page frame=range yours=tooltips | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope | host=page frame=range yours=otherpage | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=names yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=names yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=names yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=names yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=plates yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=plates yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=plates yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=plates yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,variant,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=cast yours=here | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=cast yours=row | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=cast yours=tooltips | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=cast yours=otherpage | rows=part,variant,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=range yours=here | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=yes setting=reset |
| style-reset-scope-retail | host=page frame=range yours=tooltips | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |
| style-reset-scope-retail | host=page frame=range yours=otherpage | rows=part,frame,all widest="Everything in Style" counted=yes setting=reset | rows=part,page widest="Everything on this page" counted=no setting=kept |

## Expectations changed
Existing checks, ledger answers or rules whose expectation this fix changes (`audit.py oldtests`, the guard).
Each needs the user's OK before the commit, quoted here.
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a page's Reset menu (reachable on Name Style and Range Hint's page today; Nameplate Style, Layout and
Cast bars hide Reset). A player who relied on one pick to reset all of Style now resets the page. The window's
menu, Studio.ResetWrites/Reset and every Reset page are unchanged (pinned: the window's 20 cells, both clients).
Not proven offline: the menu as drawn in game (its words and counts on the real pages' hosts; the matrix builds
each page's host with its page's options on the stand-in).
