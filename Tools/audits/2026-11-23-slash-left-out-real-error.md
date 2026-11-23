# Settings: a real error in a command shows with a part left out (fix card)
Fix: with a part left out (Visions, Cameras, Style or Atmosphere), a command's real bug indexing another table's
missing field (`entry.frame.x`, "attempt to index field 'frame' (a nil value)") got the "you've left out" note and no
error whenever ns had no key of that name.
Found by: audit 2026-11-22 (Open in `2026-11-22-settings-slash-left-out.md`)
Code: Slash.lua: LeftOutField, HandleSlash wrapper
Clients: both
Base: 2deb1a9

## Before / after
- Before: Atmosphere left out, a command's code reads `entry.frame.x` with no frame: "That needs Atmosphere, which
  you've left out..." and no error.
- After: the game's error (to the error handler, stack whole). An index counts as the left-out part's only when the
  command read ns for that name and found nothing (`ns.X.y`, X gone): while the command runs, ns gets a metatable
  whose __index notes each missing key read, taken off after.

## Who relies on the old behavior
(`python -I Tools/audit.py refs SlashLeftOutField LeftOutNote`)
- Players: only those with a part left out running a command whose code has a real bug of this kind.
- Other features: none (the wrapper is the slash command's). ns has no metatable in the game; if one is ever set,
  the watch stays off and an index error shows as an error (never a false note).
- Other addons: none.
- Tests that encode it: Tools/offline/auditsettings.lua check 2 (calls LeftOutField directly with call errors and a
  local: unchanged, kept). Tools/offline/lazyaudit.lua sets its own ns metatable but doesn't run commands through it.

## States (the matrix)
Same matrix as `2026-11-22-settings-slash-left-out.md`: a part left out (none / Atmosphere) x how the command's code
fails, per client. 14 cells.
Test: Tools/offline/slashleftoutmatrix.lua forever
Test: Tools/offline/slashleftoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| slash-leftout | leftOut=atmosphere fails=otherField | note | error |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only commands run with a part left out, and only errors that index a missing field. Kept: a missing ns call
(named or '?') still gets the note; a call to a missing field ns has, a nil local and other errors still show as
errors. Not in the matrix: a command indexing a left-out part's ns table (`ns.X.y`, X a part's): the __index watch
notes it, so it keeps its note; not proven in game. A command whose code reads ns for a missing name and then indexes
another table's field of the same name would still get the note (rare). The metatable is on ns only while the
command runs (a timer the command starts runs after, unwatched: its errors weren't caught before either).
