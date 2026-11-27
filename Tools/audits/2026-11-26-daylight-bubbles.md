# DaylightUI: our bubble look back while its own Chat bubbles toggle is off (fix card)
Fix: with DaylightUI's chat on but its own Chat bubbles toggle off, nothing styled the bubbles: our look stood aside for good since c65bdfc
Found by: release review 2026-11-26
Code: Support/DaylightUI.lua: the bubblesStyle yield (ns.AddStyleYield)
Clients: both
Base: 679e735

## Before / after
- Before: DaylightUI's chat part on, its Chat bubbles toggle (DaylightUI_Chat/Options.lua, `bubbles`) off:
  the game's plain bubbles, our Chat Bubble Style look never applied, the page not shown.
- After: the same, but our bubble look applies again with the player's saved bubble settings (as before
  c65bdfc, when the old Conflicts row's Theirs read `dui:Get("Chat","bubbles") == true`). Its toggle on, or not
  read yet (DaylightUI not loaded, or its Chat module not on yet: it comes on at login): ours stands aside, as now.
  The page still isn't made: our pages are made at our ADDON_LOADED (Options.lua's ns.OnLanguage build), and
  DaylightUI loads after us with its saved settings (DaylightUIDB) then, so the page can't know the toggle.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AddStyleYield bubblesStyle "Bubble Style"`, read every hit.)
- Players: DaylightUI users with its Chat bubbles toggle off (it's on by default). Their saved bubblesStyle and
  bubble look settings come back into use; they can't change them without the page (open question).
- Other features: ns.StyleOn("bubblesStyle") (UI/Bubbles.lua's per-bubble look and its event watcher, read live),
  ns.StylePageGone. The page's absence (ns.PageGone) unchanged.
- Other addons: Support/EllesmereUI.lua and ElvUI.lua have their own Conflicts rows: unchanged.
- Tests that encode it: Tools/offline/dlsupport.lua check 4 (its stand-in has no Chat setting: unread, still
  aside: PASS). noaddons.lua (nothing registered without it): unchanged.

## States (the matrix)
DaylightUI not loaded yet or loaded; its Chat bubbles toggle unread (nil), on, off; the Bubble Style page's
switch on or off; the client. Its chat part will load in every cell (else nothing is registered: noaddons.lua).
Test: Tools/offline/dlbubblesmatrix.lua forever
Test: Tools/offline/dlbubblesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| dl-bubbles | dui=loaded theirs=off page=on | look=off page=gone | look=on page=gone |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only DaylightUI users with its Chat bubbles toggle off. Not proven offline: the real DaylightUI's
`Get("Chat","bubbles")` reading false after its toggle is turned off in its settings (its module's db), and our
look on the game's bubbles then (in game). Its Chat module switched off inside DaylightUI (Get reads nil) still
stands aside, as before this fix.
