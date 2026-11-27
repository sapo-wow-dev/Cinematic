# Style editor: Cast Bars' Nameplates settings follow Default, and Reset puts them back to following (fix card)
Fix: on Cast Bar Style (the Nameplates variant), with Default's value changed every setting that followed it showed edited, and its x or Reset page pinned Default's default as the nameplates' own
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/Studio/Frames/CombatBand.lua: PlateField (its default, follows); Style/Studio/Editor.lua: Moved (new), ResetTo (new), Studio.SourceOf, Studio.ResetWrites
Clients: both
Base: e0ca9065ba70b460efc1b6485acec750446c45a9

## Before / after
- Before: each Nameplates cast setting is the nameplates' own (<key>_PLATE) or, empty, Default's. The editor
  compared its value with Default's default (DEFAULTS), so with Default's Height (or a color, a font...) changed,
  every Nameplates setting still following it showed edited (the mark, the x, the page's count). Its x, or Reset
  page, wrote Default's default as the nameplates' own: the plates stopped following Default and kept that value
  (Default changed again: the plates no longer did). A value of their own reset the same way: pinned to Default's
  default instead of following Default. A value of their own equal to Default's (Default changed to it later)
  showed as not edited when Default was at its default, and Reset everything in Style left it.
- After: a Nameplates setting is edited exactly while it has a value of its own (any value, Default's included).
  Following Default is never edited, whatever Default's value. Its x, Reset page and Reset everything clear the
  own value: it follows Default again, also when Default is reset in the same step. Undo gives the own value back
  (one equal to Default's comes back following it: the same value on screen). The slider's reset mark is
  Default's value now.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateField plateOwn _PLATE ResetWrites KeyDefault`, the hits read.)
- Players: anyone who changed Default on Unit Cast Style and then opened Cast Bar Style since 679e735 (unreleased
  till v2.1.35): they saw every setting marked edited; one who pressed x or Reset page has those settings pinned
  as the nameplates' own (their saved <key>_PLATE). Not undone by this fix (their values stay theirs, now shown
  edited, and one x puts each back to following).
- Other features: the editor's other fields (unit and raid frames' Look from, Cast bars' Look from, the width
  units, PRD widths, Nothing fields) have no follows: SourceOf, ResetWrites and the swatch checks are unchanged
  for them (Moved for a string key or a field without follows is the old compare). PlateCastStyle.lua's View and
  ns.CastPlateDefault (2026-11-26-cast-plate-profiles.md) read <key>_PLATE themselves: unchanged. Hold to compare
  and hover (Studio.ShowFor) put back Get's value, which set clears when it's Default's: unchanged.
- Other addons: none.
- Tests that encode it: styleresetownmatrix.lua, styleresetscopematrix.lua, stylestudio.lua (Reset frame counts,
  Reset page), styleeditorhovermatrix.lua, castlook.lua, castplateprofilematrix.lua, castplateasmatrix.lua: all
  PASS on both clients, unchanged.

## States (the matrix)
Which setting (a slider, Height; a color, Casting's swatch: its keys go through KeyDefault), Default's value (its
default, changed), the nameplates' own (none: follows; set: a value of their own; same: one equal to Default's
now), and the action: nothing, the row's x, Reset page (the Nameplates variant), Reset everything (Default reset
in the same step), set to Default's value, the x then Undo. The client.
Test: Tools/offline/castplatefollowmatrix.lua forever
Test: Tools/offline/castplatefollowmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cast-plate-follow | default=changed own=none action=none | before=yes own=none edited=yes | before=no own=none edited=no |
| cast-plate-follow | default=changed own=none action=setdefault | before=yes own=none edited=yes | before=no own=none edited=no |
| cast-plate-follow | default=changed own=none action=xundo | before=yes own=none edited=yes | before=no own=none edited=no |
| cast-plate-follow | default=changed own=none action=x | before=yes own=def edited=no | before=no own=none edited=no |
| cast-plate-follow | default=changed own=none action=page | before=yes own=def edited=no | before=no own=none edited=no |
| cast-plate-follow | default=changed own=none action=all | before=yes own=none edited=no | before=no own=none edited=no |
| cast-plate-follow | default=changed own=set action=x | before=yes own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=changed own=set action=page | before=yes own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=changed own=set action=setdefault | before=yes own=none edited=yes | before=yes own=none edited=no |
| cast-plate-follow | default=changed own=same action=x | before=yes own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=changed own=same action=page | before=yes own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=changed own=same action=xundo | before=yes own=none edited=yes | before=yes own=none edited=no |
| cast-plate-follow | default=same own=same action=none | before=no own=def edited=no | before=yes own=def edited=yes |
| cast-plate-follow | default=same own=same action=setdefault | before=no own=def edited=no | before=yes own=def edited=yes |
| cast-plate-follow | default=same own=same action=x | before=no own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=same own=same action=page | before=no own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=same own=same action=all | before=no own=def edited=no | before=yes own=none edited=no |
| cast-plate-follow | default=same own=same action=xundo | before=no own=def edited=no | before=yes own=none edited=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only Cast Bar Style's Nameplates settings (the only fields with follows). The user's call, pinned as the
fix has it: a Nameplates value of its own equal to Default's now (own=same) counts as edited and Reset clears it
(the alternative, "not edited, kept", left it pinned and edited after Reset everything). Undo of an x on such a
value gives it back following Default (the same value; set can't keep a value equal to Default's). Not proven
offline: the row's mark and x drawn on the page in game, and the slider's reset mark at Default's value.
