# Cooldown Manager: Missing and the drain ring never compare a secret (fix card)
Fix: UI/CooldownMissing.lua compared icon.cooldownID with == / ~= (secret in fights, as Frames.lua's ItemSpell has it); in the SetShown hook (Bring -> Wanted -> NamesOf) nothing caught the error. Its Show() in fights was untested on retail. UI/CooldownRing.lua tested a possibly secret count and amount with == nil.
Found by: release review 2026-11-23 (v2.1.28; Missing from b2d8578)
Code: UI/CooldownMissing.lua: InUse (new), NamesOf, IconFor, CooldownMissingShows, Wanted, Bring, Visit; UI/CooldownRing.lua: Charges, the ring's amount check
Clients: both
Base: 4d01a3a

## Before / after
- Before: a secret cooldown ID read twice (NamesOf's kept.id == icon.cooldownID) gave a Lua error from the hook, every time the game hid a Missing icon. On retail our Show() ran in fights though only Forever proved it safe.
- After: type() / issecretvalue only on the ID; a secret ID counts as an icon in use and uses the names kept from when it read plain. On retail, in a fight, the Missing icon is not shown by us (counted as refused, as a Touchable refusal), shown again by the first pass after the fight. Forever unchanged (Show proven in fights: rule forever.cooldownviewer.show-hidden-buff-icon, ledger Tools/tests/cdm-missing-buff.md Q6, 38 of 38 looks, no errors). The ring's `count == nil` / `amount == nil` are `type(x) == "nil"`: same result for plain values.

## Who relies on the old behavior
- Players: retail players with a buff on Missing lose the reminder in fights (until retail is tested, ledger Q9 open).
- Other features: ns.CooldownBuffNames, ns.CooldownBuffOnYou, ns.CooldownMissingShows (Frames.lua ns.CooldownBuffShows), the ring's Charges / amount (no behavior change for plain values).
- Other addons: none.
- Tests that encode it: Tools/offline/cdmmissing.lua (forever, unchanged, PASS), cdmring.lua, cdmringgroupmatrix.lua; Dev/CdmGridTest.lua steps missing/missingfight (Forever).

## States (the matrix)
The cooldown ID plain or secret (a new stand-in secret on every read, comparing two errors), in a fight or not, the buff off or on you, the client.
Test: Tools/offline/cdmmissingsecretmatrix.lua forever
Test: Tools/offline/cdmmissingsecretmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdmmissing-secret-forever | id=secret buff=off | error (secret compare) | shown=true ours=true refused=0 |
| cdmmissing-secret-retail | id=secret buff=off fight=no | error (secret compare) | shown=true ours=true refused=0 |
| cdmmissing-secret-retail | id=secret buff=off fight=yes | error (secret compare) | shown=false ours=true refused=3 |
| cdmmissing-secret-retail | id=plain buff=off fight=yes | shown=true ours=true refused=0 | shown=false ours=true refused=3 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Forever behavior unchanged except no Lua error on a secret ID. Retail: the Missing reminder no longer shows in fights (a choice: Show() there unproven; drop the `ns.isRetail and InCombatLockdown()` gate in Bring once retail Q9 is tested). Not proven offline: that `== nil` on a secret errors in game (Lua 5.1 never calls __eq against nil; the matrix proves the two-secret compare only); the ring's type() checks are behavior-preserving by reading.
