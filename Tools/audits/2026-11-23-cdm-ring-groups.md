# Cooldown Manager: Ring and Amount follow a buff group's lead (fix card)
Fix: with buffs counted as one (Demon Skin + Demon Armor), the Ring set on the group's row drew only on the lead's icon; the others never got one, and their Amount read their own old row
Found by: release review 2026-11-23
Code: UI/CooldownRing.lua: RowKey (new), StyleOf, Show
Clients: both
Base: HEAD

## Before / after
- Before: Ring and Amount were looked up by each icon's own spell; the grid stores a group's settings under its lead, so a member's icon had no ring.
- After: a member's icon reads its group lead's row (ns.CooldownBuffKey), like every other column does. Not grouped: each buff its own row, as before.

## Who relies on the old behavior
- Players: only those who grouped shields and set Ring: the members now show it.
- Other features: CooldownGrid's RowKeys (the lead's row), CooldownMissing's CooldownBuffKey (same lookup).
- Other addons: none.
- Tests that encode it: Tools/offline/cdmring.lua (no groups: ALL PASS).

## States (the matrix)
Grouped or not, Ring set on the lead's row or on none, Amount on or off there, the lead's icon or the other's up; the client.
Test: Tools/offline/cdmringgroupmatrix.lua forever
Test: Tools/offline/cdmringgroupmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdmring-groups | grouped=yes ring=lead amount=on icon=other | ring=no | ring=yes amount=yes |
| cdmring-groups | grouped=yes ring=lead amount=off icon=other | ring=no | ring=yes amount=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: grouped shields with Ring on only. Not proven offline: a group of real shields in game (the ring's size is still each icon's own spell's).
