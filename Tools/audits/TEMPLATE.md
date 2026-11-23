# <Area>: <the fix in a few words> (fix card)
Fix: <one line: what was wrong, for whom>
Found by: <audit YYYY-MM-DD | player case | release review>
Code: <file: function(s)>
Clients: <both | forever | retail>
Base: <ref of the code before the fix: HEAD while it's staged, the commit's hash^ once it landed>

## Before / after
- Before: <what the player (or another feature, or another addon) saw or got, in player words>
- After: <the same, after the fix>

## Who relies on the old behavior
(`python -I Tools/audit.py refs <function> <setting> <frame>`, read every hit.)
- Players: <saved settings, defaults, built-in profiles, what they see every day>
- Other features: <callers, pages, Show in rows, cards...>
- Other addons: <Support/ files, frames they hook>
- Tests that encode it: <offline checks, Dev tests, ledgers, engine rules, other cards>

## States (the matrix)
The states this code reads, each a dimension: <card up/gone, gap within/after, row on/off, client, CineMode on/off,
in a fight or not, addon loaded or not...>. Every combination is a cell; every cell is pinned in the test.
Test: Tools/offline/<name>matrix.lua forever
Test: Tools/offline/<name>matrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| <matrix name> | <dim=value dim=value> | <old outcome or *> | <new outcome or *> |

## Expectations changed
Existing checks, ledger answers or rules whose expectation this fix changes (`audit.py oldtests`, the guard).
Each needs the user's OK before the commit, quoted here.
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
<low | medium | high>: <who could notice, how often, what's pinned against it, what isn't (in-game only)>
