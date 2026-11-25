# Atmosphere: the haze loop off where its Show in row says no (fix card)
Fix: the edge haze's loop ran every frame in CineMode where its Show in row said off (nothing drawn)
Found by: audit 2026-11-25 (gating, finding D14 in 2026-11-25-gating-findings.md)
Code: Atmosphere/Focus.lua: the loop's wanted
Clients: both
Base: baabf86

## Before / after
- Before: Haze strength up (or a script's Edge haze), Haze on, in CineMode, its Show in row saying no (its
  rule to start with: the camera modes only, so most of CineMode): nothing drawn, but its update ran every frame.
- After: no loop there. Its row coming on starts it within the second (the loops' once-a-second look),
  before the haze's 3-second pull in. What draws doesn't change.

## Who relies on the old behavior
(`python -I Tools/audit.py refs depthOfField effectWanted`)
- Players: nothing they see changes.
- Other features: /cine doftest and the slider preview (a demo: loop on whatever the row says, unchanged).
- Other addons: none.
- Tests that encode it: Tools/offline/focusloopmatrix.lua pins row=no as loop=on (its card,
  2026-11-23-focus-haze-loop.md, wrote down what the code did then). That pin changes: needs the user's OK.

## States (the matrix)
The existing focus-haze-loop matrix: strength, a script's haze, CineMode, the Haze switch, its row, a demo; the client.
Test: Tools/offline/focusloopmatrix.lua forever
Test: Tools/offline/focusloopmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| focus-haze-loop | cine=on dof=on row=no demo=none | loop=on draws=no | loop=off draws=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/focusloopmatrix.lua | pins "strength=up cine=on dof=on" and "script=haze cine=on dof=on", their row=no demo=none cells | loop=on draws=no | loop=off draws=no | yes, the user 2026-11-25 (picked "1 Haze loop"); pins edited |

## Risk
low: its WantedStrength already returns 0 there. Up to a second before the pull starts when the row comes
on (the pull takes 3 s). Not proven in game: a camera mode starting in CineMode.
