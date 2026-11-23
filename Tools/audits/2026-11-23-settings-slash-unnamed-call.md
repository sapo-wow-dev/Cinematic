# Settings: commands into a left-out part say so again (field '?') (fix card, retroactive)
Fix: after bdb2e1d only a missing ns call named in the error counted as a left-out part's; Lua 5.1 names some calls'
field "?", so such a command (/cine doftest with Atmosphere left out, Forever) gave a bare error, no note.
Found by: release review 2026-11-22; fixed in ae2cda8
Code: Slash.lua: LeftOutField
Clients: both
Base: ae2cda8^

## Before / after
- Before: Atmosphere left out, /cine doftest: a Lua error.
- After: "That needs Atmosphere, which you've left out (its General page's Load box)." with the error under it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs SlashLeftOutField LeftOutNote`)
- Players: those with a part left out running a command into it.
- Other features: none.
- Other addons: none.
- Tests that encode it: Tools/offline/auditsettings.lua check 2 "an unnamed missing call" (added with the fix).

## States (the matrix)
Same matrix as `2026-11-22-settings-slash-left-out.md`: a part left out x how the command fails, per client. 14 cells.
Test: Tools/offline/slashleftoutmatrix.lua forever
Test: Tools/offline/slashleftoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| slash-leftout | leftOut=atmosphere fails=unnamed | error | note |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: retroactive. A real bug in a call Lua names '?' with a part left out is now shown as the left-out note (its
error text under it, not in the error window).

## Open (user's call)
- `fails=otherField` FAILs on this code and the current one (pinned "error"): see the other card's Open.
