# Hunter: the right-click pull watch only while it's on (fix card)
Fix: every Classic Era hunter ran a watch every frame from login (mouse buttons, the mouseover enemy, the state driver), with the Hunter page off (its default) or the right-click setting unticked
Found by: audit 2026-11-25 (gating, finding D4 in 2026-11-25-gating-findings.md)
Code: QoL/Hunter.lua: the PLAYER_LOGIN watch (ns.SetOnUpdate -> ns.FeatureLoop), ns.RefreshHunterPull (new); Options.lua: the Hunter page switch's onChange; Profiles/Profiles.lua: SettingsChanged
Clients: Classic Era only (the file returns on every other client)
Base: baabf86

## Before / after
- Before: a hunter on Classic Era with the Hunter page off: a watch ran every frame for the whole session.
- After: it runs only while Right click attack also uses Auto-shot is on with its page, and for a moment
  after switching it off, to let go of the right-click binding and the fight's state driver. Switching it
  on starts it within a second (at once from the page switch or a profile).

## Who relies on the old behavior
(`python -I Tools/audit.py refs hunterRightClickShot handleHunter ApplyDriver`)
- Players: hunters with it on: same watch, same work each frame.
- Other features: none.
- Other addons: none.
- Tests that encode it: none offline (no Classic Era load before this one).

## States (the matrix)
The Hunter page on or off, the right-click tick on or off, what the cell before left (on or off).
Test: Tools/offline/hunterpullmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| hunter-pull-loop | page=off | loop=on | loop=off |
| hunter-pull-loop | page=on tick=off | loop=on | loop=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the watch's body is unchanged; only when it runs. Ticking the setting on from its own box starts the
watch on the next once-a-second sync (up to a second). Not proven offline: the real right-click pull on
Classic Era, and the binding let go while the right button is held (the watch waits for it, as before).
