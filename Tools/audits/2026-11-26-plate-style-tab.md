# Nameplates: the Style tab's switch turns Nameplate Style's plates off (fix card)
Fix: the Nameplates page's Style tab switch (tabOn:Nameplates:PlateStyleShow, the tab holding Nameplate Style's Show in row) was read nowhere: off, Smart's marks and Default's colors still showed
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Plates/PlateIcons.lua: ns.PlateStyleTabOff, PlateIconWanted (TargetArrow, KindColors); Plates/PlateParts.lua: ns.PlateKinds.On
Clients: both
Base: e0ca906

## Before / after
- Before: switching the Style tab off changed nothing on the plates.
- After: the tab off, Smart's marks (and every row's look, colors, opacity and size, which go by their level) fade
  out and Default's colors go, whatever the Show in row says, as the Nameplates page's other tabs are containers.
  The tab on: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateStyleShow PlateDefaultColoursOn`, every hit read.)
- Players: the tab is on by default (LazyPageDefaults.lua); only someone who switched it off sees a change.
- Other features: ns.PlateDefaultColoursOn (ns.PlateKinds.On) also gates the editor's preview of Default's colors
  (PlateRowLook.lua): with the tab off the preview shows none, as with Nameplate Style off.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
The tab on/off x the Nameplates page on/off x Nameplate Style on/off x Smart on/off x Default's color set or not x
the Show in row showing them (Always out of CineMode, Always in it, Out of combat ticked in CineMode; its off states
are Tools/offline/platecolorsshowmatrix.lua's), no row fitting, settled, the client.
Test: Tools/offline/platestyletabmatrix.lua forever
Test: Tools/offline/platestyletabmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-style-tab | tab=off style=on smart=off default=set | smart=0.00 bar=kind@1.00 | smart=0.00 bar=- |
| plate-style-tab | tab=off style=on smart=on default=set | smart=1.00 bar=kind@1.00 | smart=0.00 bar=- |
| plate-style-tab | tab=off style=on smart=on default=unset | smart=1.00 bar=- | smart=0.00 bar=- |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players who switch the tab off. Pinned: every switch above it, both clients. Not proven offline: the
tab's switch on the page in game (greyed with the Nameplates page off, read all the same), and the marks fading out
as it's switched off.
