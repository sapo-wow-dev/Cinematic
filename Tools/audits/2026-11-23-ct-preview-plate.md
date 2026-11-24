# Combat Text Style: sample numbers on the plate you see (fix card)
Fix: on WoW Forever, when the preview's game plate copy wasn't built (the template failing, or the game's options not ready yet), the preview showed the drawn plate but Combat Text Style's sample numbers (the page's and the welcome window's demo) played over the hidden game plate's spot
Found by: release review 2026-11-23 (v2.1.28; bdc70d4 / 479114f)
Code: Plates/PlateRowLook.lua: ns.MakePlateRowLookPreview (holder.plate set by Refresh, holder.drawnPlate); Style/CombatTextPage.lua: the page's preview and Play, ns.ShowCombatTextDemo
Clients: both
Base: C:/Users/casal/AppData/Local/Temp/claude/749a148a2801cb3d/c52daf98-75d2-4f7a-b7d0-87b1d7987cf3/scratchpad/prefix-tree (a copy of the worktree before this fix, on 4d01a3a; these two files had no other uncommitted change when copied. Once landed: this fix's commit^)

## Before / after
- Before: holder.plate was the game plate frame whenever ns.MakeGamePlate made one (always on Forever), built or not. The page placed only that frame (at plateLift) and drew its numbers on it: with the copy not built, the drawn plate showed at the preview's middle and the numbers played at the hidden frame's spot.
- After: each Refresh points holder.plate at the plate it shows (the game's copy when built, else the drawn one). The page and the demo place both plates (the game's at plateLift, the drawn one at 44 / 1.6 over its cast bar, as on retail) and read preview.plate as each number plays. With the copy built: unchanged.

## Who relies on the old behavior
(`python -I Tools/audit.py refs holder.plate gamePlate plateLift MakePlateRowLookPreview`, every hit read.)
- Players: only Forever players whose copy fails (rare: logged "game plate copy not used").
- Other features: holder.plate is read only by CombatTextPage.lua (page and demo); Nameplate Style's own page uses holder.gamePlate and gameLift / gameScale (unchanged).
- Other addons: none.
- Tests that encode it: Tools/offline/gameplate.lua "the preview's plate is it (Combat Text draws on holder.plate)", checked before the first Refresh (kept: holder.plate starts as the game frame; passes); platecopyevents.lua, platematch.lua (Dev/PreviewMatch.lua: not holder.plate).

## States (the matrix)
The client, the game plate's copy built or failing (ns.GamePlateReady), the page's preview or the welcome window's demo.
Test: Tools/offline/ctpreviewplatematrix.lua forever
Test: Tools/offline/ctpreviewplatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| ct-preview-plate | client=forever copy=fails | on=game shown=no lift=66.0 | on=drawn shown=yes lift=27.5 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Forever with the copy built and retail are unchanged (pinned, page and demo). The drawn fallback plate on Forever now sits at the bottom over its cast bar instead of the preview's middle. Not proven offline: the on-screen spot of the numbers over the drawn plate (the stand-in has no layout), and the copy becoming ready later in a session (the next Refresh points holder.plate at it; the numbers read it as they play).
