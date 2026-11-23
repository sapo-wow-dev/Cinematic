# Addons: Questie loading late reads its support box as at login (fix card)
Fix: Questie loaded after login, its support box changed meanwhile: its setup read the box as it is now, our paths into Questie's support as it was at login, so the two disagreed.
Found by: questiegatematrix (retro state tests of bdb2e1d / ae2cda8), 2026-11-23; the user's call: "Yes, keep both" (as at login)
Code: AddonSupport.lua: OnLoaded (a setup's gate), ns.AddonSupportOffAtLoad (the at-login record, shared with ns.AddonUp)
Clients: both
Base: 74bf070

## Before / after
- Before: box unticked, then Questie loads: setup skipped, but tooltips, item button and target mark still used
  Questie's support. Box ticked again, then Questie loads: setup ran, but none of those paths ran.
- After: both follow the box as it was at login, as the box says (it counts after a reload).

## Who relies on the old behavior
- Players: Questie loaded on demand or late (rare), box changed in the same session.
- Other features: every addon's setup goes through OnLoaded (DaylightUI, Leatrix, DialogueUI...): at login the
  record and the live box are the same; the Addons page itself still shows the live box (ns.AddonSupportOn).
- Tests that encode it: questiegatematrix (pins already said "as at login"), questiegate.lua, noaddons.lua.

## States (the matrix)
questiegatematrix: Questie none / at login / late x the box off, on, unticked or reticked after login.
Test: Tools/offline/questiegatematrix.lua forever
Test: Tools/offline/questiegatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| questie-gate | questie=late box=unticked | setup=no asks=tip,wait,item,mark,icon | setup=ran asks=tip,wait,item,mark,icon |
| questie-gate | questie=late box=reticked | setup=ran asks=none | setup=no asks=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (the matrix's pins already said so; the user, 2026-11-23: "Yes, keep both") | | | | |

## Risk
low: a late-loading addon's setup with its box changed since login. The record is now also taken as the first
setup asks (at load), so an untick before any ask no longer counts at once.
