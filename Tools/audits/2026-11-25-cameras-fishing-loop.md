# Fishing: no per-frame watch with the Fishing page off (fix card)
Fix: with a fishing pole in your main hand, the right-click cast watch ran every frame although the Fishing page was off
Found by: audit 2026-11-25 (gating, finding D11 in 2026-11-25-gating-findings.md)
Code: Camera/Camera.lua: the recast watcher's FeatureLoop wanted()
Clients: both
Base: baabf86

## Before / after
- Before: Fishing page off, a pole equipped (or the fish camera on, or fishing): the watch runs every
  frame, doing nothing (its keys need the page).
- After: it runs only with the page on, or while keys of ours are still bound or a reel setting still
  held, so they're given back as the page goes off.

## Who relies on the old behavior
(`python -I Tools/audit.py refs handleFishing recastWatcher FishCamOn`)
- Players: none (the page off, the watch set nothing).
- Other features: the fish camera (its own code) doesn't need this watch; the clean-up of our keys
  (bound, REEL_CVARS, reelHeldUntil) still keeps it on until done.
- Other addons: none.
- Tests that encode it: none found.

## States (the matrix)
A pole on or not, the Fishing page on or off, no keys of ours bound.
Test: Tools/offline/fishingloopmatrix.lua forever
Test: Tools/offline/fishingloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| fishing-loop | pole=on page=off | loop on | loop off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more condition, true whenever the page is on. Not proven offline: the page going off live
with keys bound (the clean-up branch is kept by next(bound)).
