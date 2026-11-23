# Other addons: the support box counts after its reload (fix card)
Fix: after bdb2e1d, ns.AddonUp read the Addons page's support box live, so unticking it stopped our own put-back code at once (Questie's target icon left hidden, plate icons left moved till the reload); now it's read as it was at login.
Found by: release review 2026-11-22 (ae2cda8; retroactive card, 2026-11-23)
Code: AddonSupport.lua: ns.AddonUp(), OffAtLoad(), ns.ForgetAddonSupportAtLoad()
Clients: both
Base: ae2cda8^

## Before / after
- Before (bdb2e1d): unticking an addon's support stopped every path into it at once, our put-back code too; ticking
  it back on brought the paths back before the reload, with its setup still not run.
- After: the box counts after a reload, as its tooltip says: until then everything stays as it was at login.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AddonUp addonSupportOff ForgetAddonSupportAtLoad`)
- Players: anyone unticking or ticking a support box (Options.lua 18660, the CINEMATIC_SUPPORT_RELOAD popup).
- Other features: every ns.AddonUp caller (see 2026-11-22-addons-questie-gate.md). ns.AddonSupportOn (setups,
  Support/DialogueUI.lua, WhyFeatures) still reads the box live.
- Tests that encode it: Tools/offline/questiegate.lua check 2 ("unticked, no reload yet: still up", added here),
  Tools/offline/noaddons.lua.

## States (the matrix)
The same matrix as the bdb2e1d card: Questie (none / login / late) x its box (on / off / unticked / reticked).
Test: Tools/offline/questiegatematrix.lua forever
Test: Tools/offline/questiegatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| questie-gate | questie=login box=unticked | setup=ran asks=none | setup=ran asks=tip,wait,item,mark,icon |
| questie-gate | questie=login box=reticked | setup=no asks=tip,wait,item,mark,icon | setup=no asks=none |

## Found next to it
`audit.py card --new ae2cda8`: two cells changed that this commit didn't mean to, both Questie loading late (after
login) after the box was changed, where its setup (ns.AddonSupportOn, live) and its paths (ns.AddonUp, at login) now
disagree:
- `questie=late box=unticked`: setup=no asks=none -> setup=no asks=tip,wait,item,mark,icon (paths on, setup not run).
- `questie=late box=reticked`: setup=ran asks=all -> setup=ran asks=none (setup run, paths off).
Both FAIL their pins on the current code.

## Open (user's call)
- `questie=late box=unticked` / `box=reticked`: pinned "as at login" (unticked: setup=ran asks=all; reticked:
  setup=no asks=none), the box's own words ("after a reload"). The other reading: an addon loading late after the
  change has nothing to put back, so it could follow the box at once (unticked: none at all; reticked: all). Either
  way setup and paths should agree; today they don't.
- The box is read at the first ns.AddonUp call, not at login: unticked before anything asked ns.AddonUp, it counts at
  once. Offline that's every cell with no play first; in game most likely something asks within the first frames.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card; questiegate.lua check 2 gained a check) | | | | |

## Risk
low: one read moved from live to cached. Not proven offline: the plate put-back paths (PlateParts' moved icons),
when the cache first fills in game.
