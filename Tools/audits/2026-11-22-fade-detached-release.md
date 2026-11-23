# FadeDetached: a part handed back while it refuses our code (fix card)
Fix: a part that ignores its frame's alpha is faded with the frame by FadeDetached.lua; handed back (it stops
ignoring its parent) while it refused addon code (a fight on WoW Forever), Release wrote to it: a forbidden-object
error from our hook, and, its record already dropped, its own alpha was never given back.
Found by: audit 2026-11-22; fixed in bdb2e1d (retroactive card, 2026-11-23)
Code: FadeDetached.lua: Release() (not Usable: kept taken), its callers Apply() (checked already) and OnIgnore().
(Also in bdb2e1d: Drain sets its walker's loop once, not every call: perf only, no player state, no matrix.)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: a part another addon detaches and then re-attaches in a fight (EllesmereUI's chat dock on Forever) while
  its frame is faded: a Lua error, and the part left at the faded alpha till a reload.
- After: no error; kept faded until a later look (the next time Cinematic sets its frame's alpha) finds it
  reachable, then its own alpha is back.

## Who relies on the old behavior
(`python -I Tools/audit.py refs OnIgnoreParentAlpha SyncDetached`)
- Players: anyone fading frames whose parts another addon detaches (FlareUI's gryphons, EllesmereUI); nobody relies
  on the error.
- Other features: every ns.SyncDetached caller (Frames.lua's fade, action bar art stand-in), /cine why's
  ns.DetachedFor, Tools/offline/gryphons.lua.
- Other addons: FlareUI, EllesmereUI (they detach and re-attach parts).
- Tests that encode it: Tools/offline/fightsfades.lua check 5 (kept), gryphons.lua.

## States (the matrix)
handed back by (unignore: it stops ignoring / rootup: its frame comes up) x the part (reachable / refusing) x the
later look (frame up / faded again), per client. 8 cells per client.
Test: Tools/offline/detachedreleasematrix.lua forever
Test: Tools/offline/detachedreleasematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| detached-release | how=unignore reachable=no | release=error later=faded | release=faded later=own |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: one guard. Not proven offline: when the "later look" comes in game (the frame's alpha set again: each fade
step, or not till the next fade), so how long a re-attached part stays faded after a fight.

## Found next to it
On the old code the error inside Release also left the file's `busy` flag set (busy = true; SetAlpha errors; never
reset), so every later hand-back and fade of a detached part did nothing for the session: the matrix resets it per
cell to keep cells apart. The current code still sets busy around unguarded SetAlpha calls in Release and Apply: a
write that errors for another reason (a part that passes ns.Reachable but still refuses) would stick it the same
way. Not fixed here (report only).
