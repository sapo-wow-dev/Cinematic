# Plate Layout: Balanced counts only what can show, by kind (fix card)
Fix: Balanced counted the marker, elite mark, buffs and crowd control on every plate whether they were up or not, so a
plain mob was moved over (31 in run qd5a8); and every kind was balanced as a hostile mob, crowd control and buffs
too, though the game never draws them on a friendly NPC's plate (nor crowd control on a player's).
Found by: audit 2026-11-25 (findings 6 and 9); the default is the user's pick ("Count while shown")
Code: Plates/PlateLayout.lua: ns.PlateLayoutShift, ShownParts, ns.PlateLayoutCountOf / ns.PLATE_LAYOUT_DEFAULT_COUNT
and NEVER_ON (new); Plates/PlateLayoutPage.lua: the Balance list's default
Clients: forever (no layout on retail)
Base: HEAD

## Before / after
- Before: with Center on Balanced, every part counted always unless set otherwise, so room was kept for a marker,
  an elite mark, buffs and crowd control on every plate; friendly NPCs and players were balanced on room for parts
  the game never draws on them.
- After: the marker, elite mark, buffs and crowd control count only while they're up on that plate (an aura row
  only with an icon in it), the bar, name, level box, cast bar and the rest always; any part's Balance list still
  sets its own. Crowd control and buffs never count on a friendly NPC's plate, crowd control never on a player's.

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased.
- Tests that encode it: Tools/offline/platelayout.lua's Balanced checks (written when everything counted: their
  layouts now say Always counts for those parts, their expected results unchanged); fix 1's matrix pins Balanced
  shifts made under the old default (8 cells, below); Dev/PlateMatchTest.lua's Balanced check (every part up, level
  box and crowd control left out) holds either way.

## States (the matrix)
Fix 1's matrix (level box shown / hidden, the layouts, Center Bar / Balanced) carries the change: its Balanced cells.
Test: Tools/offline/platelayoutmatrix.lua forever
New checks in Tools/offline/platelayout.lua: the default with nothing rare up; crowd control up on a hostile mob
(counted) and on a friendly NPC (not).

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-levelhidden | level=shown layout=none center=balanced | cc=bar+30 shift=19 | cc=bar+30 shift=9 |
| platelayout-levelhidden | level=shown layout=ccNudged center=balanced | cc=bar+40 shift=14 | cc=bar+40 shift=9 |
| platelayout-levelhidden | level=shown layout=levelMoved center=balanced | cc=bar+40 shift=14 | cc=bar+40 shift=4 |
| platelayout-levelhidden | level=shown layout=ccHung center=balanced | cc=bar+8 shift=30 | cc=bar+8 shift=9 |
| platelayout-levelhidden | level=hidden layout=none center=balanced | cc=bar+5 shift=31 | cc=bar+5 shift=21 |
| platelayout-levelhidden | level=hidden layout=ccNudged center=balanced | cc=bar+15 shift=26 | cc=bar+15 shift=21 |
| platelayout-levelhidden | level=hidden layout=levelMoved center=balanced | cc=bar+5 shift=31 | cc=bar+5 shift=21 |
| platelayout-levelhidden | level=hidden layout=ccHung center=balanced | cc=bar+8 shift=30 | cc=bar+8 shift=21 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/platelayoutmatrix.lua | the 8 Balanced pins | shift 19 14 14 30 / 31 26 31 30 | shift 9 9 4 9 / 21 21 21 21 | the user, 2026-11-25: "OK" |
| Tools/offline/platelayout.lua | the 4 Balanced checks' layouts | every part counting by default | the marker, elite, buffs, crowd control set to Always counts; results unchanged | the user, 2026-11-25: "OK" |

## Risk
low: the Layout tab's Balanced only, unreleased. Aura rows' icons come and go without the row showing or hiding: the
layout listens to the game's own row refresh (RefreshList) to center again. Not offline: that refresh on live plates
and the re-centering as a marker or an aura comes and goes (the in-game run).
