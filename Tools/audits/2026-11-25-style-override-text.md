# Style: parts rows repaint with Style left out (fix card)
Fix: with Style left out, the HUD Unit Frames and Nameplates parts rows threw a Lua error each time they painted
Found by: audit 2026-11-25 (gating, finding A1 in 2026-11-25-gating-findings.md)
Code: Modules.lua: MODULE_STAND_INS.style (StyleOverrideText)
Clients: both
Base: badf2f0

## Before / after
- Before: Load Style unticked, open the HUD's Unit Frames page or the Nameplates page: every parts row
  (Portrait, Name, Health bar...) calls Style's "Overridden: hidden" words, which aren't loaded. A Lua
  error per row, on opening the page and each time it refreshes.
- After: the rows paint as with no override (Style's overrides can't apply with Style out anyway:
  ns.StyleOverride is already a stand-in giving nothing).

## Who relies on the old behavior
(`python -I Tools/audit.py refs StyleOverrideText`)
- Players: nobody; the error only shows with Style left out.
- Other features: Options.lua:9166 (UnitPartRow) and 11257 (plate parts rows), the only callers.
- Other addons: none.
- Tests that encode it: none. stylebacklinks.lua nostyle builds every page but never repaints a row.

## States (the matrix)
Each part (Visions, Cameras, Style, Atmosphere) loaded or left out; every page made, every frame with a
Refresh repainted; the outcome is whether any called a function that isn't there.
Test: Tools/offline/partrowsmatrix.lua forever
Test: Tools/offline/partrowsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| part-rows-repaint | part=style state=out | * | ok |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a stand-in that returns nothing, used only while Style is left out, where the real function's answer
is nothing too (its ns.StyleOverride is a stand-in giving nil). Loaded, the real function wins (stand-ins
fill only a missing ns key). Not proven in game: the page opening with Style out.
