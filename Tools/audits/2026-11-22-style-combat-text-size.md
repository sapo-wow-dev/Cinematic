# Style: combat text keeps growing past the font's largest size (fix card)
Fix: Size, Crit size and a long cast go to 300% x 300% x 150% of 36, but the game draws no font past 120, so big numbers stopped growing there.
Found by: audit 2026-11-22 (landed in bdb2e1d; this card written after, retroactively)
Code: Style/CombatTextStyle.lua: SetSize() (font at 120 at most, the words scaled the rest), SetHeight() (a pop's height in the font's own size)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: a number asked for past 120 (a 300% crit, 140) drew at 120, the same as a smaller one; its edge and
  shadow copies too.
- After: the font at 120 and the words scaled the rest: the number and its copies draw at the size asked. A crit's
  pop still peaks at 1.2 times it. Below 120 nothing changes.

## Who relies on the old behavior
(`python -I Tools/audit.py refs combatTextSize SetTextScale`, read every hit.)
- Players: anyone with Combat Text's Size, Crit size or long-cast size high enough to pass 120 (Size over ~233%
  for plain hits, less for crits).
- Other features: none read number.textScale but SetHeight; Combat Vision has its own FONT_MAX (CombatVision.lua).
- Tests that encode it: Tools/offline/combattextsize.lua (140 and 36 only); engine rule
  forever.font.max-height-120 (tested on Forever, retail untested); ledger Tools/tests/self-text-page.md Q3.

## States (the matrix)
The size asked (36 below, 120 at, 140 above, 486 far above), the font string with or without SetTextScale, All
texts' Edge (the game's shadow, or edge and shadow), a tag line or none, the picked font taken or refused (the
game's then), a fresh number or one reused from a 486 one; per client. 128 cells. The stand-in draws SetFont at 120
at most (the engine rule) and a SetTextHeight uncapped, times the words' scale.
Test: Tools/offline/combattextsizematrix.lua forever
Test: Tools/offline/combattextsizematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combattext-size | size=above textScale=has edge=game tag=no | number=120 copies=120 tag=none pop=168 | number=140 copies=140 tag=none pop=168 |
| combattext-size | size=above textScale=has edge=game tag=yes | number=120 copies=120 tag=70 pop=168 | number=140 copies=140 tag=70 pop=168 |
| combattext-size | size=above textScale=has edge=both tag=no | number=120 copies=120,120 tag=none pop=168 | number=140 copies=140,140 tag=none pop=168 |
| combattext-size | size=above textScale=has edge=both tag=yes | number=120 copies=120,120 tag=70 pop=168 | number=140 copies=140,140 tag=70 pop=168 |
| combattext-size | size=far textScale=has edge=game tag=no | number=120 copies=120 tag=none pop=583 | number=486 copies=486 tag=none pop=583 |
| combattext-size | size=far textScale=has edge=game tag=yes | number=120 copies=120 tag=120 pop=583 | number=486 copies=486 tag=120 pop=583 |
| combattext-size | size=far textScale=has edge=both tag=no | number=120 copies=120,120 tag=none pop=583 | number=486 copies=486,486 tag=none pop=583 |
| combattext-size | size=far textScale=has edge=both tag=yes | number=120 copies=120,120 tag=120 pop=583 | number=486 copies=486,486 tag=120 pop=583 |

## Open (the user's call)
- **The tag line past 240** (`size=far tag=yes textScale=has`, 8 cells per client): the tag is capped at 120 and
  not scaled, so next to a 486 number it draws at 120, not half (243). Pinned 243 (half, as at every smaller size):
  FAILs on the old and the current code alike. If a tag that stops at 120 is fine, re-pin it 120.
- The pop: modeled as SetTextHeight uncapped (old code popped a capped 120 number to 168, a jump then a drop). If the
  game caps SetTextHeight at 120 too, the old pops were 120 and the "pop" values change in game: unproven offline.
- Retail's 120 cap is untested (the engine rule is Forever's); the matrix assumes it on both.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: SetSize/SetHeight only; 96 of 128 cells unchanged per client (below/at 120, no SetTextScale, reused numbers
back at scale 1), the 32 changed all declared. Not proven offline: SetTextHeight's cap, retail's font cap.
