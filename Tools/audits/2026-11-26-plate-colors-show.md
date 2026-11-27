# Nameplate Style: Default's colors follow the Show in row, faded (fix card)
Fix: Default's Colors painted at full wherever Smart's marks weren't up, whatever the Show in row said, and snapped in and out as CineMode came and went
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Plates/PlateParts.lua: UpdatePlateParts (levels.KindColors), RefreshTargetArrow, TintTarget, Blend, the plate-added watcher; Plates/PlateIcons.lua: PlateIconWanted (KindColors), ns.PlateKindColoursWanted
Clients: both
Base: e0ca906

## Before / after
- Before: with a Default color set, plates took it at full strength whenever Smart's level was 0: out of CineMode
  with no Always tick, with nothing ticked in the Show in row ("When the marks and their colors show on the
  plates"), and always with Smart off. With Smart on they went at Smart's level while it was above 0, so leaving
  CineMode they faded out with the marks, then snapped back to full once the marks were gone.
- After: Default's colors have their own level from the same Show in row as the marks: its Always, or in CineMode
  the rest of it. They ease in and out at CineMode's fade times (Fade in time, Combat fade in time in a fight, Fade
  out time), never a snap; logging in, no fade. Smart on or off doesn't change them.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateDefaultColoursOn targetArrowAlways platemark:show`, every hit read.)
- Players: those who set a Default color (they start at The game's). The Show in row's Always is off by default:
  out of CineMode their colors now go unless they tick it. The Cinema and Shoulder Cam profiles tick it
  (targetArrowAlways=true): unchanged for them.
- Other features: the row's tooltip already says it covers the colors. Smart's rows' own colors still go by the
  marks' level (unchanged). The editor's preview isn't gated by the row (unchanged).
- Other addons: none.
- Tests that encode it: none (Tools/offline/targetmarksgatematrix.lua: the marks' TargetArrow, unchanged).

## States (the matrix)
Default's color set or not x Nameplate Style on/off x Smart on/off x the Show in row (Always, Out of combat ticked:
CineMode only, nothing) x CineMode on/off x settled or a quarter through the change, no row fitting, the client.
Test: Tools/offline/platecolorsshowmatrix.lua forever
Test: Tools/offline/platecolorsshowmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-colors-show | default=set style=on show=none | bar=kind@1.00 | bar=- |
| plate-colors-show | default=set style=on show=cinemode cine=off phase=settled | bar=kind@1.00 | bar=- |
| plate-colors-show | default=set style=on smart=off show=cinemode cine=on phase=fading | bar=kind@1.00 | bar=kind@0.25 |
| plate-colors-show | default=set style=on smart=off show=cinemode cine=off phase=fading | bar=kind@1.00 | bar=kind@0.75 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: everyone with a Default color set and no Always tick loses the colors out of CineMode (as the row says).
Pinned: every Show in row state, in and out of CineMode, settled and mid-fade, Smart on and off. Not proven offline:
the fade out after leaving CineMode in game (Effects' UpdatePlates skips the pass once plates are settled out of
CineMode: the marks go the same way), each tick's RefreshMarks while the colors fade (every plate, as the marks'),
and a plate added mid-fade taking the level then.
