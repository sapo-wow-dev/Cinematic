# Nameplates: a preview fades as a plate of its sample's kind (fix card)
Fix: a nameplate preview (no unit) took Default's Fade of hostile NPCs: a friendly player's, neutral NPC's... sample faded as a hostile NPC, a row's Fade off didn't keep it flat, and General's preview never showed Default's Fade
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/PlateHealthStyle.lua: PreviewKind (new), Gradient, StylePlate, ns.StylePlateBar
Clients: forever (the previews' game plate, PlateCopy.lua, is Forever's; retail draws its own and its live plates are unchanged)
Base: e0ca9065ba70b460efc1b6485acec750446c45a9

## Before / after
- Before: with no row Fade of its own, a bar fades as Default's Fade for its unit's kind (Nameplate Style's
  Colors). A preview's plate has no unit, and ns.PlateKindFade(nil) is the hostile NPCs'. Nameplate Style's
  preview: shown once as a hostile NPC (a plate theme, a Fade), then switched to Friendly player, Neutral, Enemy
  player, Friendly, Player or Not your kill whose kind has no Fade, it kept the hostile NPCs' Fade. A row's Fade
  set to off didn't keep the preview flat (ns.StylePlateBar turned its false into nil) and it faded as hostile
  NPCs'. General's preview (a hostile NPC) never showed Default's Fade (no unit: left alone).
- After: a preview fades by its own sample's kind (PlateCopy.lua's plate.kind; Not your kill with its Tapped
  state on), as a live plate of that kind does: none set for it, flat; a row's Fade off, flat; a row's own Fade,
  that. General's preview shows the hostile NPCs' Fade as their live plates do. Live plates: unchanged.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateKindFade StylePlateBar SetGamePlateUnit plateKindFade_`, the hits read.)
- Players: anyone looking at Nameplate Style's or General's preview with a Fade on one kind (since 679e735).
  Nothing saved changes.
- Other features: ns.StylePlateBar's callers: PlateRowLook.lua's sample preview (its look already carries the
  sample kind's Fade when it has one, so only the no-Fade and row-off cases change), DressGamePlateForRow (no
  callers today), GeneralStyle.lua's preview (and Style/StyleDemos.lua through it), Dev/PlateMatchTest.lua. The
  live plates (StylePlate with a unit) read the same kind as before; a live plate with no readable unit is
  unchanged (still the hostile NPCs', only previews have plate.gamePlate). ns.PlateKindFade is unchanged.
- Other addons: none.
- Tests that encode it: gameplate.lua, platekindcolors.lua, platematch.lua, platefullwhite.lua: PASS, unchanged.

## States (the matrix)
Where (a live plate with its unit; Nameplate Style's preview with its sample; General's preview, a hostile NPC),
the kind shown (hostile, neutral, friendly NPCs, enemy and friendly players, Not your kill, you: the Player
sample), which kinds have a Fade (none; only hostile NPCs'; only the kind shown; every kind its own), the row's
Fade (none, off, its own), drawn first or again (the plate or preview shown before as a hostile NPC with every
Fade: a plate reused, a sample switched). The client: retail has the live plates only (no game plate preview),
its cells unchanged.
Test: Tools/offline/platekindfadematrix.lua forever
Test: Tools/offline/platekindfadematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plate-kind-fade-forever | where=preview drawn=again row=none fades=hostile | hostileNpcs | flat |
| plate-kind-fade-forever | where=preview drawn=again row=off | hostileNpcs | flat |
| plate-kind-fade-forever | where=general kind=hostileNpcs row=none | flat | hostileNpcs |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: previews only (Forever), nothing saved. The row-off part (ns.StylePlateBar keeping a row's Fade off) and
General's preview now taking Default's Fade go beyond the bug as reported: both needed so a preview matches a
live plate of its kind (without the first, the new gate faded a row-off preview). Not proven offline: the
previews' gradient drawn in game (the stand-in records SetGradient / SetVertexColor), and the Tapped state's
sample on a real client.
