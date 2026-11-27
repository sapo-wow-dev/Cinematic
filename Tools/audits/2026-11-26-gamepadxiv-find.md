# Gamepad XIV support: what it changes in the pinned matrices (fix card)
Fix: none of its own. Gamepad XIV support (Support/GamepadXIV.lua, new) adds its interact prompt's row, "Gamepad XIV
prompt" on Advanced Frames, and on retail /cine find "gamepad" now lands on that row first, as the pinned findrank
matrix shows. This card declares that cell so `audit.py prerelease` (against v2.1.35) knows it's meant.
Found by: release review 2026-11-26 (`audit.py diff Tools/offline/findrankmatrix.lua retail --base v2.1.35`)
Code: Support/GamepadXIV.lua (new): the prompt's row
Clients: both (only retail's cell changes)
Base: e0ca906

## Before / after
- Before: on retail, /cine find gamepad put "Gamepad action bars [Mouseover groups]" first.
- After: "Gamepad XIV prompt [Advanced Frames]" first, then the rest as before. Forever: unchanged (its own
  Gamepad Frames page stays first).

## Who relies on the old behavior
- Players: none saved; a search's order only.
- Tests that encode it: Tools/offline/findrankmatrix.lua's retail gamepad pin (changed with the user's OK).

## States (the matrix)
The query (every one findrank pins), the client. Retail only here: Forever's findrank cells don't change (0 changed
since e0ca906, its run kept by 2026-11-23-find-hide-minimap.md), and the matrix has one name on both clients.
Test: Tools/offline/findrankmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| findrank-top | client=retail query=gamepad | Gamepad action bars [Mouseover groups] | Gamepad XIV prompt [Advanced Frames] |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/findrankmatrix.lua | client=retail query=gamepad pin | Gamepad action bars [Mouseover groups] | Gamepad XIV prompt [Advanced Frames] | the user 2026-11-26: "Keep new order" |

## Risk
low: a search's first hit on retail. Gamepad XIV itself is Forever's addon; its rows exist on both clients.
