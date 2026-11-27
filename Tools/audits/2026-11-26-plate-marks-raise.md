# Nameplate Style: retail's marks raises back on Smart (fix card)
Fix: retail players had no way to move Smart's marks up or down: 679e735 moved the All marks line (targetArrowY, targetArrowBareY) to Nameplate Layout's Smart marks part, and Nameplate Layout is Forever's only
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Options.lua: CreateNameStylePanel's Smart part (the All marks line, retail only)
Clients: retail (Forever unchanged)
Base: e0ca906

## Before / after
- Before: on retail, Smart's All marks line was gone and Layout's Smart marks part is never shown (the platelayout
  frame is `shown = not ns.isRetail`, ns.CreatePlateLayoutPage returns early): the two raises kept whatever value
  they had (a built-in profile's -10 or yours) with nothing to change them.
- After: on retail, Smart has its All marks line again, as before 679e735 (Raise with a plate, without a plate).
  Forever: unchanged, the raises are on Layout's Smart marks part only.

## Who relies on the old behavior
(`python -I Tools/audit.py refs targetArrowY targetArrowBareY`, every hit read.)
- Players: Cinema and Shoulder Cam profiles set targetArrowY -10 (both clients); unchanged, now editable on retail.
- Other features: PlateParts' marks read both raises (unchanged); ns.PageSettings now lists both on Nameplate Style
  on retail (they were on no page there).
- Other addons: none.
- Tests that encode it: Dev/StyleStudioTest.lua (Forever's Layout Smart marks part: unchanged).

## States (the matrix)
The client (fixed), the setting. Each cell: the pages that hold it.
Test: Tools/offline/platemarksraisematrix.lua forever
Test: Tools/offline/platemarksraisematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-marks-raise-retail | client=retail key=targetArrowY | none | Nameplate Style |
| plate-marks-raise-retail | client=retail key=targetArrowBareY | none | Nameplate Style |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: retail only, a line that was there before 679e735 put back. Not proven offline: where the line sits on
retail's Smart tab (after the grid, as before) and that it doesn't overlap the Smart rows' drawers.
Reported, not fixed (Plates/PlateParts.lua, another helper's file): on Forever with Nameplate Layout off, the two
sliders on Layout's Smart marks part are greyed but PlateParts' Style("targetArrowY"/"targetArrowBareY") still
applies them (page-switch-gates-all).
