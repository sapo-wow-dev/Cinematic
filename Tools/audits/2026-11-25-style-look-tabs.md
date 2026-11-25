# Style: a Style page's tab switched off gives its looks back (fix card)
Fix: a Style page read through ns.StyleLook asked only the page's switch, never the tab its setting is on: a tab right-clicked off kept its look
Found by: audit 2026-11-25 (gating, finding C2 in 2026-11-25-gating-findings.md)
Code: Style/StylePages.lua: ns.StyleLook (its proxy)
Clients: both
Base: baabf86

## Before / after
- Before: Chat Bubble Style on, its Bubbles tab right-clicked off: bubbles kept the Dark back (and every other
  look on that tab); Behind Bubbles off: speech from behind you kept its size, rise and fade. The same on every
  Style page read through the look with tabs, but CDM, Overrides and Combat Text's Texts, which ask by hand.
- After: a tab off gives that tab's settings their defaults (the game's look); the other tab keeps its own.

## Who relies on the old behavior
(`python -I Tools/audit.py refs StyleLook MasterOff`)
- Players: anyone with a Style tab switched off (default all on): that tab's look now goes back to the game's,
  as the tab's own tooltip says (turns everything on this tab off).
- Other features: every ns.StyleLook reader (Style/*.lua, UI/Bubbles.lua, UI/Speech.lua, Visions/Cards.lua,
  Atmosphere/LowHealth.lua and ManaVision.lua...). A setting is only changed where its switch tree has a switch
  off (ns.MasterOff): checked over every default key, the only switches above them are pages, tabs and hubs,
  never an optional tick, so nothing else reads differently. CDM (CdmStyleTabOn), Overrides (TabOf) and Combat
  Text's Texts keep their own checks; this only adds the same answer (their matrices unchanged).
- Other addons: none.
- Tests that encode it: cdmiconshape, cdmpandemicmatrix, cdmroundmatrix, bubblehookmatrix, bubblesgatematrix,
  combattextsizematrix, ctpreviewplatematrix, lazytabsmatrix: all PASS on the new code, both clients.

## States (the matrix)
Bubble Style's page switch, its Bubbles tab, its Behind Bubbles tab, the client.
Test: Tools/offline/styletabsmatrix.lua forever
Test: Tools/offline/styletabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-look-tabs | page=on bubbles=off behind=off | bubble=ours behind=ours | bubble=game behind=game |
| style-look-tabs | page=on bubbles=off behind=on | bubble=ours behind=ours | bubble=game behind=ours |
| style-look-tabs | page=on bubbles=on behind=off | bubble=ours behind=ours | bubble=ours behind=game |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a player with a Style tab switched off sees a change, and it's what the tab says. Each look read
walks the switch tree once more (a few table reads). Not proven in game: the bubbles redrawn live on the tab's
right-click (the page's Changed runs on the tab's switch as on the page's).
