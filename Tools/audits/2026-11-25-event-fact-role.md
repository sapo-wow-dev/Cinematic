# Rules: your role asked after a spec or role change, not every working out (fix card)
Fix: with a rule naming tank, healer or damage, the rule facts asked your spec and group role on every full working out (every 0.1 s, 0.5 s idle), though the game announces every change
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the role entry (ns.AddEventFact), ns.RuleFacts (the role lines)
Clients: both
Base: 0986748

## Before / after
- Before: tank, healer and damage asked ns.PlayerRole (GetSpecialization, GetSpecializationRole, UnitGroupRolesAssigned) every full working out while a rule named one.
- After: asked once, then after PLAYER_SPECIALIZATION_CHANGED, ACTIVE_TALENT_GROUP_CHANGED, PLAYER_TALENT_UPDATE, PLAYER_ROLES_ASSIGNED, GROUP_ROSTER_UPDATE or a loading screen (and for 0.5 s after each). Same words.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlayerRole`, read every hit.)
- Players: rules naming tank, healer or damage (built-in profiles: none). Heal Vision, the plate parts and Options read ns.PlayerRole themselves: untouched.
- Other features: none read facts.tank/healer/damage but the rules.
- Other addons: none.
- Tests that encode it: Tools/offline/factswords.lua (stubs ns.PlayerRole: passes).

## States (the matrix)
The states: your role tank or not, nothing new or changed with PLAYER_SPECIALIZATION_CHANGED. A rule names tank in every cell. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever role
Test: Tools/offline/eventfactsmatrix.lua retail role

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-role | word=role start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-role | word=role start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-role | word=role start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-role | word=role start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a rule naming a role is rare. Not proven offline: that one of the five events comes for every role change on Forever (a group finder role picked with no spec, a dual-spec swap). For the test skill's run: change spec or group role with a rule naming tank.
