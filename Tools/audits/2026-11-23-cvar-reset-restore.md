# Reset: the game settings put back stay yours (fix card)
Fix: Reset Cinematic put the game's Damage numbers (and the other Combat Text Style settings) back to yours, then the page wrote its own value over them a frame later when the reload wasn't in that frame
Found by: audit 2026-11-23 ("does text on target for damage get reset with our reset")
Code: Core.lua: ns.RestoreCVar
Clients: both
Base: 69e9847

## Before / after
- Before: Reset Settings or Reset Everything wrote your Damage numbers setting back with a plain SetCVar. The Combat Text Style sets are kept (keep = true, 2026-11-20), so that write looked like an outside change and was undone a frame later. Your saved value was already wiped and after the reload the page is off, so nothing let go of it again: Damage numbers on your target stayed off for good (on, if the row said Game's). Only when a frame passed before the reload (the "Type /reload to finish" fallback); the reset popup's own Reload (Forever's secure button, retail's ReloadUI) reloads in the same frame.
- After: ns.RestoreCVar lets go of the setting (heldCVars, any pending write-back) and writes yours as the addon's own write (WriteCVar): nothing writes ours back, whatever the reload's timing.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RestoreCVar`, every hit read.)
- Players: nothing they rely on: their own value back was always the intent ("the game settings Cinematic changed go back to yours" in the reset popup).
- Other features: callers Music.lua (music volume/enable), ShowMe.lua (music), Graphics.lua (Graphics+ put back), Core.lua's speed keeper (left-over camera speeds), Bubbles.lua, QuestTalk.lua, Profiles.lua's ResetAddon. None of their settings is in a keep set; for a playerWins set the old SetCVar hook let go of the setting anyway (heldCVars and savedCVars cleared), which is what the new code does directly. New: WriteCVar runs ns.cvarWrittenHooks, so an addon keeping its own copy of settings (Support/Plater.lua) hears of yours being put back too, as it does for every other write of ours.
- Other addons: none hook RestoreCVar.
- Tests that encode it: none (refs: 0 offline, Dev, ledgers, rules, cards, memory). combattextkeep.lua and gamesettingsedit.lua still pass.

## States (the matrix)
Reset Settings or Everything; the Your damage row Cinematic's or Game's; your own value on or off; CineMode's combat text set holding the setting too or not; Keep yours on the Game Settings page or not; the setting read in the same frame as the reset or a frame later.
Test: Tools/offline/cvarresetmatrix.lua forever
Test: Tools/offline/cvarresetmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cvar-reset-restore | row=ours yours=on keepYours=no read=framelater | damage=0 (not yours) | damage=yours |
| cvar-reset-restore | row=game yours=off keepYours=no read=framelater | damage=1 (not yours) | damage=yours |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only the moment a held setting is put back. Pinned offline: all 64 reset states on both clients. Not proven offline: the game's own timing of ReloadUI against a 0-second timer, and CVAR_UPDATE arriving after the write (the setting is let go first, so it's ignored either way).
