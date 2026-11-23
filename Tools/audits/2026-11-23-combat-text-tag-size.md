# Combat text: a hit's tag grows with its number past 120 (fix card)
Fix: past size 240, a partly landed hit's tag ("(Glancing)") stopped at 120 while its number kept growing (bdb2e1d scaled the number past the font's cap, not its tag).
Found by: combattextsizematrix (retro state tests of bdb2e1d), 2026-11-23; the user's call: "Yes, keep both" (tag at half the number)
Code: Style/CombatTextStyle.lua: SetSize (the tag's font)
Clients: both
Base: 5b275ad

## Before / after
- Before: Size or Crit size 486, a glancing hit: number 486 tall, its "(Glancing)" 120.
- After: the tag is half the number at every size (243 here): its font at 120, scaled the rest, as the number.

## Who relies on the old behavior
- Players: big combat text with All texts' Tag on (default size well under 240: unchanged).
- Other features: Combat Vision's own words (unchanged), the Combat Text Style page's preview (same SetSize).
- Tests that encode it: combattextsizematrix (pins already said half), combattextsize.lua (the number, kept).

## States (the matrix)
combattextsizematrix: size (under, at, past, far past 120) x SetTextScale there or not x edge x tag x font taken or refused x a fresh or reused number.
Test: Tools/offline/combattextsizematrix.lua forever
Test: Tools/offline/combattextsizematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combattext-size | size=far textScale=has tag=yes | * | * |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (the matrix's pins already said 243; the user, 2026-11-23: "Yes, keep both") | | | | |

## Risk
low: the tag's scale past 120 only (sizes over 240). Not proven in game: SetTextScale on the tag at that size.
