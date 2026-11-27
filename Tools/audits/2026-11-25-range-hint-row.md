# HUD: no Range hint row in the player copy (fix card)
Fix: Range Hint is dev only (UI/RangeHint.lua only in CinematicDev.toc), but its HUD row was added to ns.COMBAT_SHOW on every copy: the player copy carried a "rangehint" row for a frame it hasn't
Found by: audit 2026-11-25
Code: Frames.lua: ns.COMBAT_SHOW (the rangehint row's devOnly, and the player copy's loop taking devOnly rows out)
Clients: both
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: in the player copy, a "Range hint" row (key rangehint) sat in the HUD rows and everything built from them: the Mouseover groups' rows (ns.HOVER_ROWS), the key groups' frame picker list (ns.FRAME_KEY_ROWS, under its "Range hint" heading), a "Hide/show: Range hint" key binding name, rule words and searches over the rows. The pages hid it (its frame, CinematicRangeHint, doesn't exist there), but it was a row that could do nothing.
- After: the player copy has no rangehint row in any of those lists, so the "Range hint" heading is empty and skipped. The dev copy is unchanged: the row, its heading and its binding name as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs rangehint COMBAT_SHOW HOVER_ROWS FRAME_KEY_ROWS`, read every hit.)
- Players: none can have used it (no frame, no page offered it). A saved key group or Mouseover group holding "rangehint" (only possible from a dev copy's profile shared into a player copy) keeps the key; ItemOf finds no row for it, as for any unknown key.
- Other features: ns.HOVER_ROWS, ns.FRAME_KEY_ROWS (Options.lua HEADINGS keeps its { "rangehint", "Range hint" }: a heading with no rows isn't shown), the Standard Frames sections (Options.lua SECTIONS rangehint: no rows, no section), ROW_SECTIONS / HOVER_ROW_BY_GROUP / ROW_FALLBACK maps (keys only, harmless). Shoulder Cam's Follow HUD row (Camera/ShoulderCam.lua shoulderCamFollowRangeHint) is gated on its own frame: untouched.
- Other addons: none.
- Tests that encode it: Tools/offline/rangehintplayer.lua ("its HUD row isn't offered": still passes, now with no row at all). Built-in profiles' settings come from the dev copy's run (check.lua): unchanged.

## States (the matrix)
The states this code reads: the copy (player = Cinematic.toc, dev = CinematicDev.toc, one per run) and the place a row can be listed (HUD rows, Mouseover rows, key-group picker, offered on the pages, key binding name). Client per run.
Test: Tools/offline/rangehintrowsmatrix.lua forever player
Test: Tools/offline/rangehintrowsmatrix.lua retail player
Test: Tools/offline/rangehintrowsmatrix.lua forever dev
Test: Tools/offline/rangehintrowsmatrix.lua retail dev

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| range-hint-row-player | copy=player place=combatshow | listed | none |
| range-hint-row-player | copy=player place=hoverrows | listed | none |
| range-hint-row-player | copy=player place=keypicker | listed | none |
| range-hint-row-player | copy=player place=binding | listed | none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: nobody on the player copy could use the row. Pinned offline: the dev copy keeps it in every list, both clients; the player copy has it nowhere. Not proven offline: the player copy's Key groups frame picker in game showing no "Range hint" heading (an empty heading was already skipped by the picker's menu).
