# Nameplate Style: Default's Mark part back (fix card)
Fix: a mark set on Default (othersMark*) showed on every plate with no way to change or remove it: 679e735's editor gave the Mark part to the Smart rows only
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/Studio/Frames/Nameplates.lua: markPart (its shown), MarkStyles (Default's "none" label)
Clients: both
Base: e0ca906

## Before / after
- Before: Nameplate Style's Default had no Mark tab (`markPart.shown`: not Default). A Default mark (othersMarkStyle
  other than "none", from the old drawer's Mark line, a built-in profile or a shared string) still drew over every
  plate the Smart rows didn't take (PlateParts' PlateLook, OthersOn), and nothing on the page could change or remove it.
- After: Default has the Mark tab as the Smart rows do: Mark (style), Color (and its swatch), Size, Opacity, Moving,
  each on othersMark<key> (Core's DEFAULTS: Style "none", Color "reaction", R/G/B 1, Size 1, Opacity 1, Bob false).
  Its "none" choice reads The game's (no mark: the game's own look), as the old drawer's OTHERS_STYLES had it
  (git show 679e735^:Options.lua, `OTHERS_STYLES = { { value = "none", text = L["The game's"] } }`); the rows keep
  None. L["The game's"] is not new (esES: "La del juego").

## Who relies on the old behavior
(`python -I Tools/audit.py refs othersMarkStyle markPart`, every hit read.)
- Players: anyone with a Default mark saved (othersMarkStyle not "none"): it now shows on Default's Mark tab, where
  they can change or remove it. Default's default is "none": nothing changes for anyone else.
- Other features: PlateParts reads othersMark* through ArrowSetting (unchanged). Studio.Changed / Reset already went
  over the Mark part's props on Default (they read prop.shown, not part.shown), so Reset page and the edited counts
  are unchanged.
- Other addons: none.
- Tests that encode it: Tools/offline/styleundoprofilematrix.lua (othersMarkSize through Studio.Set; unchanged).

## States (the matrix)
The variant (Default, Your target, Mouseover, Focus, Aggro on you, a row added on the page with no DEFAULTS of its
own: npcEnemy), the part's field (the tab itself, Mark, Color, its R/G/B, Size, Opacity, Moving, Mark's "none" label).
Each cell: "no part" while the variant has no Mark tab, else the key(s) the field writes and whether the plates read
what it wrote (ns.TargetMarkSetting).
Test: Tools/offline/platemarkdefaultmatrix.lua forever
Test: Tools/offline/platemarkdefaultmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-mark-default | variant=others field=part | hidden | shown |
| plate-mark-default | variant=others field=Style | no part | othersMarkStyle plate=ok |
| plate-mark-default | variant=others field=Color | no part | othersMarkColor plate=ok |
| plate-mark-default | variant=others field=RGB | no part | othersMarkR,othersMarkG,othersMarkB plate=ok |
| plate-mark-default | variant=others field=Size | no part | othersMarkSize plate=ok |
| plate-mark-default | variant=others field=Opacity | no part | othersMarkOpacity plate=ok |
| plate-mark-default | variant=others field=Moving | no part | othersMarkBob plate=ok |
| plate-mark-default | variant=others field=nonelabel | no part | The game's |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one tab more on Default, on settings the plates already read. Not proven offline: the tab's look on Default (the
tip "The row's mark over the plate." names Default as a row, as the page does), Default's preview drawing the mark
while it's picked or hovered (MakePlateRowLookPreview with "others"), and the mark's raise (Layout's Smart marks part,
targetArrowY) applying to Default's mark as to the rows'.
