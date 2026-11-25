# Core: the switch gates agree on a left-out switch, and a loop can't hang them (fix card)
Fix: ns.MasterOff (so ns.StyleOn and the options' greying) read a switch whose own part is left out as not held; ns.Setting and ns.PageSetting walked the switch tree with no step cap
Found by: audit 2026-11-25 (gating, finding F1 in 2026-11-25-gating-findings.md)
Code: Core.lua: ns.MasterOff, ns.Setting, ns.PageSetting
Clients: both
Base: baabf86

## Before / after
- Before: with Visions, Cameras, Style or Atmosphere left out, ns.Setting and ns.PageOn read that part's switches
  (Enable Visions' pages, Enable Cameras, Enable Style, Visual Effects and its pages) off, but ns.MasterOff said
  "not held", so ns.StyleOn read Tint, Letterbox and Weather Style on with Atmosphere left out, and the options
  showed those switches as flippable. A loop in the switch tree (two switches put under each other) would hang
  ns.Setting and ns.PageSetting (the game frozen); ns.MasterOff already stopped after 10 steps.
- After: ns.MasterOff says held for a switch left out itself, as ns.Setting reads it; all four gates agree. ns.Setting
  and ns.PageSetting stop after 10 steps, as ns.MasterOff. (ns.PageOn's "no value = on" kept: switches start on.)

## Who relies on the old behavior
(`python -I Tools/audit.py refs MasterOff`)
- Players: none: a left-out part's pages aren't shown, its code doesn't run.
- Other features: ns.MasterOff's callers: ns.StyleOn (Style pages' looks: now off with their own part out),
  Options.lua's greying and SwitchState (held: greyed, can't flip), Effects.lua's tooltip mode (handleTooltips, never
  left out), PlateIcons, BubbleStyle, CombatTextTexts (setting keys, never left out). None asks it of a switch whose
  part is out and wants "not held".
- Other addons: none.
- Tests that encode it: none found (`grep MasterOff Tools/offline`).

## States (the matrix)
Each switch a part marks left out, with that part out and the switch ticked; and a two-switch loop for each walking
gate.
Test: Tools/offline/gateleftoutmatrix.lua forever
Test: Tools/offline/gateleftoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| gate-left-out | switch=handleHealVision | * | off |
| gate-left-out | switch=questVision | * | off |
| gate-left-out | switch=lowHealth | * | off |
| gate-left-out | switch=emoteVision | * | off |
| gate-left-out | switch=cards | * | off |
| gate-left-out | switch=deathScreen | * | off |
| gate-left-out | switch=cameraModes | * | off |
| gate-left-out | switch=styleGeneral | * | off |
| gate-left-out | switch=visualEffects | * | off |
| gate-left-out | switch=tintStyle | * | off |
| gate-left-out | switch=letterboxStyle | * | off |
| gate-left-out | switch=weatherStyle | * | off |
| gate-left-out | switch=cycle:Setting | loops | stops: nil |
| gate-left-out | switch=cycle:PageSetting | loops | stops: nil |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only switches of a part that's left out read differently (held), and only in ns.MasterOff; the step cap only
matters for a loop, which no switch has today. Not proven in game: nothing to see (left-out pages aren't shown).
ns.PageOn (Frames.lua) walks with no cap still: another file, left for its owner.
