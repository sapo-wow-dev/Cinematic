# DaylightUI: players from before keep Roll Vision's window (fix card)
Fix: on update, DaylightUI Skins users lost Roll Vision's window at rolls: 3da7a12's Loot roll window row plays DaylightUI's while unpicked
Found by: release review 2026-11-26
Code: Migrations.lua: ns.DaylightRollsOursForOld and its step (daylightRollsOursV1)
Clients: both
Base: 679e735

## Before / after
- Before: a player who had Cinematic before this release, with DaylightUI's Skins on (its loot roll window on by
  default): after the update, DaylightUI's window plays at rolls and Roll Vision's stands aside, unasked.
- After: once, for installs from before (not ns.newInstall), the row's pick is set to Ours
  (db.conflictPicks["DaylightUI:rolls"], the account's) unless a pick is there already: Roll Vision's window plays
  and DaylightUI's is held hidden, as before. Fresh installs and Reset get the row's default (Theirs). Picks made
  later are the player's.

## Who relies on the old behavior
(`python -I Tools/audit.py refs conflictPicks DaylightUI:rolls rollWindow`, read every hit.)
- Players: existing installs; the pick is account-wide (Profiles.lua's global keys), so every profile and
  character. One who has no DaylightUI gets the pick too, unused until DaylightUI's Skins load (then Ours).
- Other features: the Addon Conflicts page and login window (Conflicts.lua): the row counts as picked, so the
  window doesn't ask about it for those players. Roll Vision (Visions/RollWindow.lua) reads ns.ConflictState.
- Other addons: Support/DaylightUI.lua's row (hide: DaylightUIRollStack held at alpha 0 with Ours).
- Tests that encode it: Tools/offline/dlsupport.lua check 1 (sets picks itself: PASS). migrate-test.lua runs
  every step on a real file.

## States (the matrix)
Fresh install or from before; the row unpicked, Theirs or Ours already; DaylightUI's roll window on or off;
Roll Vision's window on or off; the client.
Test: Tools/offline/dlrollsmatrix.lua forever
Test: Tools/offline/dlrollsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| dl-rolls-update | install=existing pick=none their=on rollWindow=on | rv=aside pick=theirs | rv=plays pick=ours |
| dl-rolls-update | install=existing pick=none their=on rollWindow=off | rv=off pick=theirs | rv=off pick=ours |
| dl-rolls-update | install=existing pick=none their=off rollWindow=on | rv=plays pick=theirs | rv=plays pick=ours |
| dl-rolls-update | install=existing pick=none their=off rollWindow=off | rv=off pick=theirs | rv=off pick=ours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one saved pick for installs from before. Not proven offline: Roll Vision's window at a real group roll
with DaylightUI's held hidden (in game); the Conflicts login window not asking about the row for those players.
