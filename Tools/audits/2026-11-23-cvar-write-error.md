# Game settings: a write that errors no longer stops watching held settings (fix card)
Fix: if SetCVar threw inside WriteCVar, writingCVar stayed true and the held settings' change check (CheckHeldCVar) was off for the rest of the session
Found by: release review 2026-11-23
Code: Core.lua: WriteCVar (callers ns.ApplyCVarSet, RestoreCVar, WriteBackOverridden, the Game Settings page's writes)
Clients: both
Base: HEAD

## Before / after
- Before: one refused write (the game erroring on a setting) and from then on a change you made to a setting a set held went unseen: the set kept it and wrote its own value back when it let go, undoing yours.
- After: the flag lets go on every path (pcall); the error still goes on to the caller as before, and the written hooks are skipped on an error as before. Your change is seen and stands.

## Who relies on the old behavior
(`python -I Tools/audit.py refs writingCVar WriteCVar`, every hit read.)
- Players: anyone whose game refused one of the addon's writes (rare).
- Other features: every WriteCVar caller gets the same error as before (error(err, 0) after the flag's reset); cvarWrittenHooks run only on success, as before.
- Other addons: none (Support/ has no hits).
- Tests that encode it: cvarresetmatrix.lua, combattextkeep.lua, gamesettingsedit.lua, platefontcvarmatrix.lua, resetcvarstest.lua (all PASS, both clients); Tools/audits/2026-11-23-cvar-reset-restore.md (RestoreCVar writes through WriteCVar: unchanged).

## States (the matrix)
Another set's write errors or not; you change the held setting or not; the client.
Test: Tools/offline/cvarwriteerrormatrix.lua forever
Test: Tools/offline/cvarwriteerrormatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cvar-write-error | otherWrite=errors yours=changed | write=error held=true value=1 | write=error held=false value=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only after a write the game refuses; the error reaches callers as before. Not proven offline: which real setting, if any, makes SetCVar throw in game (the stand-in throws on purpose).
