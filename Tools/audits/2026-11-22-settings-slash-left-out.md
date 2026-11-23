# Settings: a /cine command's error with a part left out (fix card, retroactive)
Fix: with a part left out (Visions, Cameras, Style or Atmosphere), every /cine command error that said "a nil value" was
taken for that part ("That needs X, which you've left out"), so a real bug was hidden; other errors were raised again
without their stack.
Found by: audit 2026-11-22; fixed in bdb2e1d
Code: Slash.lua: HandleSlash wrapper, LeftOutField
Clients: both
Base: bdb2e1d^

## Before / after
- Before: Atmosphere left out, a nil local in a command's code: "That needs Atmosphere..." and no error.
- After: only a call into an ns function that isn't there says so; any other failure reaches the error handler
  (stack whole).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SlashLeftOutField LeftOutNote`)
- Players: only those with a part left out on its General page's Load box who run a command into it.
- Other features: none (the wrapper is the slash command's).
- Other addons: none.
- Tests that encode it: Tools/offline/auditsettings.lua check 2 (kept; ae2cda8 added its "?" check).

## States (the matrix)
a part left out (none / Atmosphere) x how the command's code fails (a missing ns call; the same named '?' by Lua 5.1;
a call to another table's missing field named like an ns one; an index of another table's missing field; a nil local;
another error; none), per client. 14 cells.
Test: Tools/offline/slashleftoutmatrix.lua forever
Test: Tools/offline/slashleftoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| slash-leftout | leftOut=atmosphere fails=nsHasName | note | error |
| slash-leftout | leftOut=atmosphere fails=nilLocal | note | error |

## Found next to it
- **UNDECLARED, a regression of this fix:** `leftOut=atmosphere fails=unnamed` note -> error. Lua 5.1 names some
  calls' field "?" (an elseif's call on Forever: /cine doftest with Atmosphere left out); bdb2e1d's pattern
  (`[%w_]+`) didn't take it, so a real left-out part's command gave a bare error. Fixed in ae2cda8 (its own card,
  `2026-11-23-settings-slash-unnamed-call.md`); both are in v2.1.24, so no release had it. This card's diff
  against bdb2e1d keeps FAILing on that cell: it's the record of the miss.
- `leftOut=atmosphere fails=otherField` stays "note" (before and after): an index of another table's missing field
  (`entry.frame.x`, "field 'frame' (a nil value)") is taken for a left-out part whenever ns has no key of that
  name. FAILs on the current code; see Open.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: retroactive. Not proven offline: the stack the game's error window shows (the handler is counted, not looked at).

## Open (user's call)
- `fails=otherField`: pinned "error" (a real bug). The error text can't tell `ns.X.y` (a left-out part's table) from
  `entry.frame.y`; reading "index" errors as left-out only for a field ns lacks is what the code does. User's call.
- `fails=unnamed`: pinned "note" (as ae2cda8 decided): a real bug in a call Lua names '?' is hidden then.
