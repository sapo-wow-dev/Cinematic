# Nameplate Style: Aggro's mark Color can be Your target's again (fix card)
Fix: an Aggro on you row's mark Color had no Your target's choice ("same"), which its Mark (style) has and its drawer had before 679e735
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/Studio/Frames/Nameplates.lua: markPart's Color (its options, now a list per variant)
Clients: both
Base: e0ca906

## Before / after
- Before: on an Aggro row, the Mark tab's Mark offered Your target's, its Color didn't: Gold, By reaction, Class colors,
  My own only. A saved aggroMarkColor "same" (the old drawer's AGGRO_COLORS, `git show 679e735^:Options.lua`) still
  drew in your target's color but the picker showed no choice for it, and once changed it couldn't be picked back.
- After: an Aggro row's Color starts with Your target's ("same"), as AGGRO_COLORS had it (first); picking it, the
  plate's mark takes your target's Color and R, G, B (PlateParts' ArrowSetting, AGGRO_COLOR_KEYS: unchanged). Every
  other row: unchanged. "Aggro row" is a row whose base is aggro (aggro, aggro2, aggroIn28...), the rows ArrowSetting
  reads "same" for and MarkStyles offers Your target's to; Aggro on not you, not a tank, on healers (aggroother,
  aggrononank, aggrohealer, the ag mixes) had neither before or after.

## Who relies on the old behavior
(`python -I Tools/audit.py refs aggroMarkColor AGGRO_COLOR_KEYS`, every hit read.)
- Players: aggroMarkColor defaults to "custom"; anyone who picked Your target's in the old drawer has "same" saved,
  shown now as such.
- Other features: PlateParts' ArrowSetting (unchanged). C.Chips, Studio.Describe and Host:Paste call a function
  options list with no variant (Default's list, no "same"); the editor (f.pickers) draws the picker line from the
  variant's list, so the choice shows.
- Other addons: none.
- Tests that encode it: none.

## States (the matrix)
The row: Default, the unit rows, Aggro on you, one Distance's, a second one, the other aggro kinds, a row added on
the page. Each cell: the Color choices' values in order, and for a row offered "same", whether it gives the plate
your target's color.
Test: Tools/offline/platemarkaggrocolormatrix.lua forever
Test: Tools/offline/platemarkaggrocolormatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-mark-aggro-color | row=aggro | gold,reaction,class,custom | same,gold,reaction,class,custom same=target's |
| plate-mark-aggro-color | row=aggroIn28 | gold,reaction,class,custom | same,gold,reaction,class,custom same=target's |
| plate-mark-aggro-color | row=aggro2 | gold,reaction,class,custom | same,gold,reaction,class,custom same=target's |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one choice more on Aggro rows, a value the plates already read. Not proven offline: the picker showing it on an
Aggro row in game, its hover preview, and the undo line's text ("Color > same": Studio.Describe reads the list with
no variant), and Copy/Paste of the Mark tab dropping "same" (Host:Paste likewise).
