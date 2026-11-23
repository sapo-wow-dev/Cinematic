# Unit Frames: the target of target's frame isn't dressed twice a frame (fix card)
Fix: the game's target-of-target frame sets its power bar's fill and color again every frame it shows, and each set dressed all of the frame (Unit Frames' hooks), twice a frame in fights, even with nothing of ours on that bar
Found by: /perf 2026-11-23 (Forever deep fight recording 17:10: ~38 ns.StyleLook a frame from DressFrame via the bar hooks)
Code: Style/UnitStyle.lua: DressFrame's bar hooks (SetStatusBarTexture, health and power SetStatusBarColor), later.*
Clients: both
Base: 8c5baf1

## Before / after
- Before: every game set of a unit frame's bar fill or color dressed all of that frame at once: name, portrait, shape, every bar. On the target of target's frame that's every frame it shows.
- After: a set on a bar carrying ours (our fill, color, gradient, border, By health) is dressed at once as before; a green (not its power's) mana color too. A set on a bar with nothing of ours dresses the frame once a moment later (0.2 s), and at once when the frame shows another unit (its name changed, or can't be read). What the player sees is the same in every cell.

## Who relies on the old behavior
- Players: no setting changes.
- Other features: DressFrame callers (ns.RefreshUnitStyle on target/focus/pet/roster events: unchanged, still at once); KeepColor's redress (unchanged); the portrait hook (unchanged).
- Other addons: none (the hooks are on the game's own bars; nothing new hooked).
- Tests that encode it: selfframetheme.lua, unitmatch.lua, byhealthalloc.lua (run, unchanged).

## States (the matrix)
Unit Frames off, on with nothing of ours on the bars, on with our health color, or a theme (Forge); the game setting the power bar's fill and white, a green mana color, or the health bar's color; the same unit or a new one (a mage: class name color). Each cell: the frame right after the game's first set, a moment later, and whether all of it was dressed on every set through a second of them.
Test: Tools/offline/totredressmatrix.lua forever
Test: Tools/offline/totredressmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| tot-redress | look=off | * | * |
| tot-redress | look=plain | * | * |
| tot-redress | look=colored set=power | * | * |
| tot-redress | look=colored set=green | * | * |

(Only `dressed=every-frame` -> `dressed=few` changes in these cells; their now/after looks are pinned and unchanged.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: a part of the frame that the game resets with no bar set and no unit change (none known) would wait up to 0.2 s for ours. Not proven offline: the real game's set order on Forever and retail (TargetOfTargetMixin's OnUpdate), and the saving (DressFrame's body isn't timed: a normal /cine profiler fight run with a target of target up measures it).
