# Performance: no frame scan, buff walks or tracking reads for pages that are off (fix card)
Fix: the HUD off still counted as a page that fades frames (the frame scan ran on); the Buffs page off still walked every buff icon on each aura change; the minimap tracking list was read every pass with the Minimap page and Keep Open both off
Found by: audit 2026-11-25 (gating, findings D5, D6 and D15's minimap reads in 2026-11-25-gating-findings.md)
Code: Frames.lua: ns.AnyFramePageOn, PeekAllowed, ns.UpdateFrames (the tracking reads)
Clients: both
Base: baabf86

## Before / after
- Before: nothing seen; a cost. HUD switched off (Advanced Frames and Gamepad off too): the frame scan
  still ran every few seconds. Buffs page off: every aura change on you still ran the peek code, walking
  the buff icons. Minimap page and Keep Open off: the tracking list and its Except in row read each pass.
- After: none of that work with those pages off. What shows is the same: the peeks and the tracking
  keep-open were already off with their pages.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AnyFramePageOn PeekAllowed IsKeepingMinimapForTracking IsTrackingOffHere`)
- Players: none (cost only).
- Other features: Core.lua's scan (one more round as the last page goes off: unchanged), Profiles/ShowMe
  (its whole-screen demo when no page fades frames: now also with the HUD off), Dev/FadeDemoTest. The
  debuff count isn't kept while the Buffs page is off (as with both peeks unticked before): the first
  aura change after turning it back on compares with the count from before.
- Other addons: none.
- Tests that encode it: auditsettings, chatbgsettle: PASS both clients.

## States (the matrix)
frame-scan: the HUD's, Advanced Frames' and Gamepad's switches. buff-peek: the HUD's and the Buffs
page's, an aura change. minimap-tracking: the Minimap page's and Keep Open's, a frames pass.
Test: Tools/offline/perfgatesmatrix.lua forever
Test: Tools/offline/perfgatesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| frame-scan | hud=off addon=off gamepad=off | scan | none |
| buff-peek | hud=off | walked | skipped |
| buff-peek | page=off | walked | skipped |
| minimap-tracking | page=off keepOpen=off | reads=2 | reads=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: each is true with its page on. Profiles/ShowMe's demo picks "whole" with the HUD off now (nothing
it shows fades then anyway). Not proven offline: the profiler's numbers in game.
