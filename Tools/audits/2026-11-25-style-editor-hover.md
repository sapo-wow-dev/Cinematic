# Style editor: pointing at a choice never saves anything (fix card)
Fix: hovering a choice whose field writes more than its own key left those writes saved: "Its own look" hovered on the Cast bars tab started the nameplate cast bars' own copy of Default's settings for real
Found by: audit 2026-11-25 (style editors from b53755f)
Code: Style/Studio/Frames/CombatBand.lua: CastLookField, UnitOwnField, RaidOwnField, playerWidthUnit, PrdWidth (noHover, honored by Studio.ShowFor in Editor.lua and Host:Snapshot in Studio.lua)
Clients: both
Base: cc7e40d

## Before / after
- Before: on Nameplate Style's Cast bars tab, pointing at "Its own look" in Look from (without clicking) ran the
  real pick: Default's cast bar settings copied into the nameplate bars' own (plateCast*_PLATE) and
  plateCastStarted_PLATE saved; only the Own switch was put back. Picking "Its own look" later started from that
  stale copy, not from Default as it was then. Pointing at Pixels in a Width in (your cast bar, the personal
  resource bars) filled an empty pixel width for good. Unit and raid Look from: nothing (their set did nothing).
- After: these choices aren't drawn on the preview while pointed at (as every field marked noHover); nothing is
  saved until clicked. Plain settings are still drawn on hover, unsaved.

## Who relies on the old behavior
(`python -I Tools/audit.py refs noHover ShowFor CastPickLook plateCastStarted_`, every hit read.)
- Players: anyone who hovered "Its own look" on the Cast bars tab since b53755f has plateCastStarted_PLATE saved
  and a copy from that moment; not undone here (a later pick keeps that copy, as any started copy).
- Other features: Studio.ShowFor (Editor.lua) and Host:Snapshot (Studio.lua, hold to compare: Studio window only,
  no way in since b53755f) already skip a field marked noHover; nothing else reads it. The Cast Bar Style page's
  own Look from dropdown (PlateCastStyle.lua PickLook) unchanged.
- Other addons: none.
- Tests that encode it: Tools/offline/gameplate.lua (ShowFor on a plain key: unchanged), stylestudio.lua.

## States (the matrix)
The field (Cast bars' Look from on the nameplates, Unit frames' and Raid frames' Look from, Your cast bar's
Width in, Personal resources' Width in, a plain key for the other side), its saved choice, the choice hovered.
Test: Tools/offline/styleeditorhovermatrix.lua forever
Test: Tools/offline/styleeditorhovermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-editor-hover | field=cast saved=first hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=cast saved=first hover=second | * | db=unchanged drawn=none |
| style-editor-hover | field=cast saved=first hover=third | * | db=unchanged drawn=none |
| style-editor-hover | field=cast saved=second hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=cast saved=second hover=second | * | db=unchanged drawn=none |
| style-editor-hover | field=cast saved=second hover=third | * | db=unchanged drawn=none |
| style-editor-hover | field=unit hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=unit hover=second | * | db=unchanged drawn=none |
| style-editor-hover | field=raid hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=raid hover=second | * | db=unchanged drawn=none |
| style-editor-hover | field=castWidth hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=castWidth hover=second | * | db=unchanged drawn=none |
| style-editor-hover | field=prdWidth hover=first | * | db=unchanged drawn=none |
| style-editor-hover | field=prdWidth hover=second | * | db=unchanged drawn=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only the hover preview of five choices goes (they never showed safely); a click does what it did. Not
proven offline: the Cast bars tab's Look from row in game (pointing at it draws nothing, the badge "Preview: not
saved" may still show as for any row). Not fixed here, reported: Name Style's NPC titles brackets field
(Names.lua SERVICE_BRACKETS) folds two ticks into one choice, so a hover's set-back can reset
nameServiceBracketsWithName while brackets are off.
