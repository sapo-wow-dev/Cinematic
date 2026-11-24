# Cast Bars: the nameplates' look on real bars laid out as in v2.1.27 (fix card)
Fix: 8d185cd laid the real target/focus/your cast bar's icon and name out by your nameplate style when "Look like" the nameplates' was picked; on Forever with Modern/Thin the icon and name dropped under the bar and the icon shrank 12 -> 10 x scale
Found by: release review 2026-11-23 (v2.1.28)
Code: Style/PlateCastStyle.lua: Apply (passes sample on), DressAs ("plate" branch)
Clients: both
Base: HEAD

## Before / after
- Before: a player who set Cast Bars > Target (or Focus, or Your Cast Bar, boss) to the nameplates' game look saw that real bar's spell icon and name move from inside the bar to under it (Forever, nameplate style Modern/Thin/Health Focus/Legacy), at a smaller icon (10 x nameplate size scale), and with Classic style the icon off the bar's left end. Retail's moved from 1 under the bar to 0 under it and resized too.
- After: the real bars are as in v2.1.27, whatever the nameplate settings: icon 12; Forever's icon and name in the bar at its left, retail's under the bar at its left (-1). The pages' preview samples still follow your nameplate style and size (8d185cd's preview work, as OK'd).

## Who relies on the old behavior
(`python -I Tools/audit.py refs DressAs plateCastGameAs PlateCastLayout`, read.)
- Players: anyone with plateCastGameAs_<TARGET|PLAYER|BOSS> on: their real bars go back to the v2.1.27 look they had before 8d185cd (unreleased: 8d185cd isn't in a tag yet).
- Other features: Apply's callers: Restyle (real bars, sample nil), DressSample / MakePlateCastSample (previews, sample true). Only the "plate" branch reads sample; the "unit" branch is unchanged.
- Other addons: none.
- Tests that encode it: Tools/offline/castlook.lua (samples, through ns.MakeCastLookSample: previews, unchanged); Tools/offline/castframe.lua (previews); rules all.plate.castbar-layout-by-style / castbar-sizes are about the game's plates and previews, not changed.

## States (the matrix)
Real bar (TargetFrameSpellBar restyled) vs a page preview's sample; nameplateStyle 0-6; nameplateSize 1-5; the client.
Outcome: our icon's size, where our icon sits, where our name sits.
Test: Tools/offline/castplateasmatrix.lua forever
Test: Tools/offline/castplateasmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cast-plate-look | bar=live | * | * |

(One row for both clients: a client= row fails the other client's run. The after per client is pinned in the
matrix: Forever `icon=12 at=LEFT>bar.LEFT 0,0 name=LEFT>icon.RIGHT 2,0`, retail
`icon=12 at=TOPLEFT>bar.BOTTOMLEFT 0,-1 name=LEFT>icon.RIGHT 2,0`, every style and size. Preview cells: none change.)

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

(8d185cd: the pages' preview samples follow your nameplate style and size, OK'd by the user 2026-11-23; 35 preview
cells per client, each after pinned in the matrix: under the bar on Modern/Thin/HealthFocus/Legacy, in it on Block
and CastFocus, Classic's icon centered on the bar's left end, icon 10 (Forever) / 12 (retail) x the size's scale.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with a cast bar set to the nameplates' game look; the real bars go back to the released v2.1.27 layout (the matrix's live pins pass on v2.1.27 too). Not proven offline: the real bars in game (the stand-in bar is a drawn sample hung as TargetFrameSpellBar).
