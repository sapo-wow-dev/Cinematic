# Search: "hide minimap" opens the Minimap page again (fix card)
Fix: since 70613ac (Style > Minimap), /cine find hide minimap (and "how do i hide the minimap") put the Minimap Style page's "Hide" heading first, over its zoom buttons, zone bar and day/night dial; it doesn't hide the minimap. Everyone searching it.
Found by: release review (Tools/offline/findrank.lua FAIL since 70613ac)
Code: UI/Find.lua: Score (new DOING words)
Clients: both
Base: 4d01a3a

## Before / after
- Before: "hide minimap" -> Hide [Minimap Style] (score 30: "hide" its label, "minimap" its page's name) over the Minimap page (18).
- After: a heading whose whole label is one doing word (Hide, Show) counts that word as a tooltip's (2, not 10) and gets no "just the words" bonus: it scores 16, the Minimap page (18) is first again. "letterbox size" still gives Size [Letterbox Style] (Size is a thing, not a doing word).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SearchRank`, read every hit.)
- Players: no setting; only where a search lands. The only heading of one doing word in the index is Minimap Style's "Hide" (Style Overrides' Hide is a Button choice, not touched). Typing just "hide" now puts that heading lower (it was first among its rows); its three rows still come up by their tooltips ("hides the minimap's ...").
- Other features: ns.SearchRank feeds the options search box and the /cine find results window (UI/Find.lua, Options.lua).
- Other addons: none.
- Tests that encode it: Tools/offline/findrank.lua (pins the Minimap page for both queries, written in 6e4dcfa: FAILs on HEAD, PASSes after), Dev/FindResultsTest.lua (the same case, in game), Tools/offline/findcheck.lua (ids only, unaffected).

## States (the matrix)
The state ns.SearchRank reads: the query (every one findrank.lua and Dev/FindResultsTest.lua pin: lands, not What's new, each synonym but taxi) and the client. Every query is a cell; every cell is pinned in the test.
Test: Tools/offline/findrankmatrix.lua forever
Test: Tools/offline/findrankmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| findrank-top | query=hide_minimap | Hide [Minimap Style] | Minimap [Minimap] (page) |
| findrank-top | query=how_do_i_hide_the_minimap | Hide [Minimap Style] | Minimap [Minimap] (page) |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a heading labeled just "Hide" or "Show" ranks lower (today one: Minimap Style's Hide). Pinned: 106 searches on both clients unchanged. Not proven offline: the in-game index (Dev/FindResultsTest.lua's ranked step covers "how do i hide the minimap").
