# Style: the pandemic border goes round on round Cooldown Manager icons (fix card)
Fix: with Action Bar Style's Shape on Round, the game's pandemic border (the glow on a buff or DoT in its last stretch, when refreshing it is best) stayed a square around the round icon
Found by: player case
Code: Style/ActionBarStyle.lua: DressPandemic, DressCdmIcon (its hook on the icon's ShowPandemicStateFrame)
Clients: both
Base: b22b6ce

## Before / after
- Before: Round icons, a buff or DoT in its pandemic window: the game's square border and its square sweep drew
  6px outside the round icon.
- After: on Round icons, the game's square border and its sweep are hidden and a round glow of ours (the round
  buttons' proc ring, in the game's border red) pulses on the icon's edge instead. Square and the game's shape: the game's border,
  untouched.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PandemicIcon ShowPandemicStateFrame DressCdmIcon RefreshCooldownShape`.)
- Players: only those with Shape on Round see a change, and only while an icon is in its pandemic window.
- Other features: the Flash when ready (Frames.lua) and the Arcane Blast timer (UI/CooldownStacks.lua) are their
  own frames, not touched. The pandemic frame is a child of the icon: DressCdmIcon's mask for child frames is made
  on it too, but cuts nothing (its art sits a frame further down).
- Other addons: none (Support/ has no hits).
- Tests that encode it: none.

## States (the matrix)
Shape (game, Square, Round) x order (the border shown after the shape is set, shown before it, or shown while
Round and the shape changed after). Outcome: the game's border and sweep shown or hidden, our round glow shown or
not.
Test: Tools/offline/cdmpandemicmatrix.lua forever
Test: Tools/offline/cdmpandemicmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdm-pandemic | shape=round | border shown, sweep shown, ring none | border hidden, sweep hidden, ring shown |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Round-shape players only, only while a pandemic border shows. Pinned: every shape and order, both clients.
Not proven offline: the game hooks firing in a fight, our glow's color against the game's (a shot in
/cine debug cdmround's pandemic step), and a pooled border frame moving between icons.
