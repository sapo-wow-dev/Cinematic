# Cooldown Manager: the drain ring stops rebuilding a tooltip for a spell with no shield (fix card)
Fix: a Ring on a tracked buff with no "absorb N" in its text (Fortitude, an armor) built a hidden tooltip for each rank on every 0.25 s tick and every hit, for as long as the buff was up
Found by: release review 2026-11-23
Code: UI/CooldownRing.lua: DescriptionSize (tipMissed, TIP_RETRY 10 s)
Clients: both
Base: HEAD

## Before / after
- Before: a spell whose description and tooltip have no shield number was looked up again in full (SetOwner, SetSpellByID, 12 lines read) at every ring update.
- After: its tooltip is tried again after 10 seconds at most. A size once found is kept, as before; the description is still read every time (cheap), so a late description is seen at once and a late tooltip within 10 s.

## Who relies on the old behavior
- Players: none see a change (no ring draws without a size either way).
- Other features: SizeFor (each rank), ns.CooldownRingFits (another session's uncommitted page check: it keeps only yes, and asks DescriptionSize: a miss now waits 10 s before its tooltip is built again, its description still read).
- Other addons: none.
- Tests that encode it: Tools/offline/cdmring.lua (ALL PASS), cdmmissing.lua (ALL PASS).

## States (the matrix)
The description with a number or none, the tooltip with one or none, in a fight or not, asked again 2 s or 15 s later; the client.
Test: Tools/offline/cdmringsizematrix.lua forever
Test: Tools/offline/cdmringsizematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdmring-size | desc=none tip=none fight=no again=within | size=none,none scans=2 | size=none,none scans=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a shield whose tooltip only fills in late (after a /reload) gets its ring up to 10 s later than before. Not proven offline: the real tooltip's timing in game.
