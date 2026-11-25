# Style: the tooltip, buff row and minimap ring hooks rest once their pages are off (fix card)
Fix: hooks that can't be taken off kept doing their work after their Style page was switched off: every tooltip shown was dressed again, every aura layout of the target and focus frames ran the buff row's lift, and every turn of the minimap's ring turned its hidden tinted copy
Found by: audit 2026-11-25 (gating, finding D15's Style hooks in 2026-11-25-gating-findings.md; its Self Text and Combat Text tickers are in 2026-11-25-self-text-tabs.md and 2026-11-25-combat-text-general-tab.md)
Code: Style/TooltipStyle.lua: Apply (worn, new); Style/UnitAuraLift.lua: ns.UnitAuraLift's UpdateAuras hook; Style/MinimapStyle.lua: Lift's SetRotation hook, TintRings
Clients: both
Base: baabf86

## Before / after
- Before: Tooltip Style on once, then off: each tooltip shown (and each fill) ran the whole put-back, for
  good (the preview's made skins counted too). Unit Frames Style with a frame shape once, then off: each aura
  change of the target and focus frames ran the lift. Minimap Style's ring tinted once, then not: each turn
  of the ring (it turns with you on some clients) turned the hidden copy.
- After: each is put back once, then left be: a tooltip not dressed since its put-back is skipped at the
  first line; the buff row's hook is out while nothing is lifted and the page is off; the copy only turns
  while the ring is tinted, and is turned to the ring again as it shows. Pages on: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshTooltipStyle UnitAuraLift TintRings`)
- Players: none see a change: those passes only put back what was already back.
- Other features: ns.RefreshTooltipStyle (the page's switch, a conflict row on Theirs) puts every game
  tooltip back once through Apply, as before; the preview's tooltips are dressed by Dress directly and no
  longer keep the game's tooltips' hooks working. UnitStyle.lua calls ns.UnitAuraLift as it dresses a shape:
  unchanged.
- Other addons: an addon's own tooltip skin over ours (Conflicts' Theirs): StyleOn is off for it: put back
  once, as before.
- Tests that encode it: auralift, auraplate, unitmatch, minimapbuttonsmatrix, squaremap: PASS, both clients.

## States (the matrix)
What's hooked (a tooltip shown, the target's auras laid out, the minimap's ring turned), its page on or on
then off (or, for a tooltip, one never dressed while it was on); the client.
Test: Tools/offline/stylehooksrestmatrix.lua forever
Test: Tools/offline/stylehooksrestmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-hooks-rest | page=onThenOff | work=3 | work=0 |
| style-hooks-rest | what=tooltip page=neverDressed | work=3 | work=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: each skip needs its page off and what it put on already back. Not proven offline: a lift held when the
page goes off (offline the plate is a stand-in: its lift is 0; in game DressShape puts it to 0 as the shape
goes, then the hook rests), and the real ring's copy lined up as the tint comes back.
