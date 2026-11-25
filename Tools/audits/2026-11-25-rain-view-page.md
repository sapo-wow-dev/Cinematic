# Weather: the bad-weather view distance off with the Weather page (fix card)
Fix: with the Weather page off, Reduce view distance in bad weather (its slider is on that page) still brought the view distance in, in rain in CineMode
Found by: audit 2026-11-25 (gating, finding C15 in 2026-11-25-gating-findings.md)
Code: Graphics.lua: the bad weather view distance's Wanted
Clients: both
Base: baabf86

## Before / after
- Before: Reduce view distance in bad weather set above 0, then the Weather page switched off: in CineMode in
  rain, snow or a sandstorm the view distance still came in. Only Enable Visual Effects off stopped it.
- After: the Weather page off (or Visual Effects off, or Atmosphere left out) stops it too; one already in
  eases back out to yours over its usual 10 seconds.

## Who relies on the old behavior
(`python -I Tools/audit.py refs rainViewScale`)
- Players: rainViewScale is 0 in every profile and the default since 2026-11-23: only players who raised it
  and then switched the Weather page off notice, and that's the fix.
- Other features: the Weather page's Preview (still works with the page off: previews ignore the page),
  /cine debug viewdist (reads the same Wanted).
- Other addons: none.
- Tests that encode it: atmopreview.lua (defaults and migration only), Dev/AtmosphereTest.lua viewdist
  (the preview): unchanged.

## States (the matrix)
The Weather page on or off, Enable Visual Effects on or off, CineMode on or off, rain or not; the client.
Test: Tools/offline/rainviewpagematrix.lua forever
Test: Tools/offline/rainviewpagematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| rainview-page | page=off effects=on cine=on rain=yes | in | out |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one more switch read, true for everyone with the Weather page on. Not proven in game: the view
distance easing back out when the page goes off mid-rain.
