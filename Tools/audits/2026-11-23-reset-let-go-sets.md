# Reset: every held game setting let go before the reload (fix card)
Fix: with CineMode's combat text off and Combat Text Style both holding the game's Damage numbers, a reset left them off for good: the reload's logout let go of the two sets one by one after the reset had wiped your saved value
Found by: audit 2026-11-23 (the sweep after ca8a9fb)
Code: Profiles/Profiles.lua: ns.ResetAddon
Clients: both
Base: ddbae95

## Before / after
- Before: Reset Settings or Reset Everything put each saved game setting back (ns.RestoreCVar) and wiped the saved values, but the sets holding them stayed held in memory till the reload. Its logout let go of them one by one: the first to let go wrote the other's value (two sets on one setting share one saved value of yours), and the last found nothing saved to put back. With CineMode on, Hide combat text ticked, out of a fight, and Combat Text Style on, the game's Damage numbers came back off after a reset if yours were on.
- After: the reset lets go of every set still held first, as the safety stop does (RestoreEverything): the last to let go writes yours, and the logout has nothing left to write. Then the saved values left (music, chat bubbles, quest talk insets...) are put back as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ResetAddon cvarSets`, every hit read.)
- Players: no one: a reset always meant "the game settings Cinematic changed go back to yours" (the reset popup says so).
- Other features: every set's let-go is the one ApplyCVarSet already uses at logout, on CineMode off and in the safety stop; the sets only hold game settings. A feature still running before the reload (a frame or more: "Type /reload to finish") may hold one again; its logout lets go of it with yours saved (pinned: read=afterlogout runs the page's refresh first).
- Other addons: none (Support/: 0).
- Tests that encode it: none (offline: only cvarresetmatrix.lua; Dev pages read ns.cvarSets, none resets).

## States (the matrix)
The matrix of 2026-11-23-cvar-reset-restore.md, with the read after the reload's logout added (read=afterlogout: the page's two-second refresh, then PLAYER_LOGOUT).
Test: Tools/offline/cvarresetmatrix.lua forever
Test: Tools/offline/cvarresetmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cvar-reset-restore | yours=on cinemode=held keepYours=no read=afterlogout | damage=0 (not yours) | damage=yours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only the reset, just before its reload. Pinned offline: 96 reset states on both clients. Not proven offline: secure (plate and name) sets in a fight wait for its end (the reset is refused in a fight anyway), and the other logout steps run on the real game (Music, plates, camera speeds): stubbed here.
