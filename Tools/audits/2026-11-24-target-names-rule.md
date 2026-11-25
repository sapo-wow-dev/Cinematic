# Names: a Target names rule decides your target's name both ways (fix card)
Fix: PlateAlphas (Effects.lua): with a rule on the Target section's Names row (name:YourTarget), your target's name goes by that row alone; its kind's row, the group rows and Service NPCs no longer keep it up (nor put a title in its place). The Mouseover names row still adds.
Found by: player case 2026-11-24 (Discord, DialogueUI): Target names "not npc" left a vendor's title up through the talk, Service NPCs keeping it
Code: Effects.lua: PlateAlphas (targetDecides), the Why lines; Options.lua: the row's tooltip
Clients: both
Base: 4669fcc

## Before / after
- Before: the Target names row only added: a rule saying no ("Right now: hidden" in the editor) still left your target's name up wherever its kind's row or Service NPCs kept it, a vendor's turning into its title.
- After: with a rule, the rule decides your target's name both ways. Without a rule (ticks only, every profile's start), as before. NPCs you haven't targeted: as before.

## Who relies on the old behavior
- Players with a Target names rule that says no somewhere while a kind row shows those names (say "not combat" with Friendly NPCs always up): their target's name now goes there. The editor's "Right now: hidden" said so already; the tooltip says it now.
- Nobody without a Target names rule: no rule by default.

## States (the matrix)
Targeted or not; Target names rule none / yes / no; Friendly NPCs row up or down; a Service NPCs title or none.
Test: Tools/offline/talknamesmatrix.lua forever
Test: Tools/offline/talknamesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| target-names-rule | target=yes rule=no kind=up service=match | name=1 text=1 | name=0 text=1 |
| target-names-rule | target=yes rule=no kind=up service=none | name=1 text=1 | name=0 text=1 |
| target-names-rule | target=yes rule=no kind=down service=match | name=1 text=0 | name=0 text=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Dev/HoverPlateTest.lua | page: Mouseover nameplates under the Target section's Names row; Mouseover names right under it | names rows on the Nameplates icon's Target tab | Mouseover nameplates under Your target's Nameplates row; no names rows there (Names icon's own Target tab) | user, 2026-11-24: "Build it" (plan Tools/npc-words-plan.md: Names > Target tab) |

## Risk
low: only players with a Target names rule; one rule lookup per pass, for your target's plate only. All names (the other half of the same plan) is Always to start: no change till edited (Tools/offline/talknames.lua). In game: proven on Forever (talknames q11ff 7/7, page qa44a 8/8, mouseplate page q03d6 4/4, 2026-11-24); not on retail, not with DialogueUI. The plate pass's settled check now also wakes on the All names and Target names answers (run 3 faded 2 s late).
