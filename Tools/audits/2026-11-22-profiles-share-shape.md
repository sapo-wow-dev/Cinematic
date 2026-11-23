# Profiles: a shared profile's lists of the wrong shape refused (fix card, retroactive)
Fix: a profile string's (or backup's) list settings were taken as any table. The Follow HUD's undo list is written
back entry by entry (FollowHud.lua Restore), so an imported one could write an account setting (Enable) or error;
a Mouseover group that isn't a table errored where its preset is read.
Found by: code audit 2026-11-22; fixed in bdb2e1d (card written after, 2026-11-23)
Code: Profiles/Profiles.lua: ns.KnownProfileSetting, ns.ProfileTableShaped, ns.FollowHudEntryOk;
Profiles/FollowHud.lua: Restore
Clients: both
Base: bdb2e1d^

## Before / after
- Before: importing a hand-made or broken string could bring a Follow HUD list whose Undo turned Cinematic off
  (an undo entry for Enable), errored on Undo (an entry that isn't a table, an undo that isn't a list), or wrote
  any setting it named; a Mouseover group of the wrong kind came in and errored later.
- After: such a list is left out of the import whole (counted as skipped); the rest of the profile comes in.
  Lists of our own shape come in as before; Undo skips anything that isn't a profile setting's entry.

## Who relies on the old behavior
(`python -I Tools/audit.py refs KnownProfileSetting ProfileTableShaped FollowHudEntryOk`)
- Players: strings made by Cinematic always have our shapes: nobody's real string changes.
- Other features: Profiles/Share.lua ReadSharedProfile, Profiles/Backups.lua Known (restore), Dev/Prerelease.lua.
- Tests that encode it: Tools/offline/shareshape.lua (added with the fix); this matrix.

## States (the matrix)
Where it comes in (a pasted string, a backup restored) x what the list holds: the Follow HUD's (good, picks only,
picks not a list, undo not a list, an entry that's a number, with no key, for Enable, for a debug setting, for an
unknown key, with a row of the wrong kind, with a good row), Mouseover groups (good, no members, a number, members
not a list), and a plain Show in list (a table, a word). Outcome: taken or left out; for a Follow HUD taken, what
Undo then does (the Mouseover switch put back, Enable). 34 cells per client.
Test: Tools/offline/shareshapematrix.lua forever
Test: Tools/offline/shareshapematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| share-shape | value=hud-picks-string | * | left out |
| share-shape | value=hud-undo-string | * | left out |
| share-shape | value=hud-entry-number | * | left out |
| share-shape | value=hud-entry-nokey | * | left out |
| share-shape | value=hud-entry-account | * | left out |
| share-shape | value=hud-entry-debug | * | left out |
| share-shape | value=hud-entry-unknown | * | left out |
| share-shape | value=hud-entry-rowbad | * | left out |
| share-shape | value=groups-number | * | left out |
| share-shape | value=groups-members-string | * | left out |

(20 cells per client. Before: taken; Undo errored for hud-entry-number and hud-undo-string, and turned Enable off
for hud-entry-account.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Open (user's call)
- A Follow HUD list with one bad entry is left out whole (pinned so), not kept with that entry dropped: the
  profile then has no Follow HUD to undo.

## Risk
low: only strings or backups not made by Cinematic. Not proven offline: the import window's skipped count shown.
