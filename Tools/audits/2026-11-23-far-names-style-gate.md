# Plates: plates one size only when our names are styled (fix card)
Fix: on WoW Forever in CineMode with Enable Style off (or the Style part left out), the game's plates were still held one size (nameplateMinScale = MaxScale = 1) though we draw no names on them: the game's plates stopped shrinking with distance for nothing ("a page switch off gates all")
Found by: release review 2026-11-23 (v2.1.28)
Code: Effects.lua: ns.plates.FarWanted; UpdatePlates (a duplicate ApplyCVarSet of FAR_NAME_CVARS after FarStepChanged removed)
Clients: forever
Base: C:/Users/casal/AppData/Local/Temp/claude/749a148a2801cb3d/c52daf98-75d2-4f7a-b7d0-87b1d7987cf3/scratchpad/prefix-tree (a copy of the worktree before this fix: the uncommitted far-names work, Tools/audits/2026-11-23-far-names-step.md, on 4d01a3a. Once that work is committed, this is its commit)

## Before / after
- Before: FarWanted read the raw saved Name Style tick only: with Enable Style off, or the Style part left out, CineMode still held the game's plates one size. A never-set Name Style (nil) read as off, though PlateParts styles names on its default (on).
- After: held only as PlateParts styles names: ns.StyleOn() (Enable Style, off with the Style part left out: LEFT_OUT_SWITCHES) and Name Style (its default when unset), every plate on, Forever, the name jump test not holding it off. The second ApplyCVarSet after FarStepChanged is gone: FarStepChanged makes the same call, and both return early in a fight (FarStepChanged's InCombatLockdown, the secure set's), so it did nothing.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FarWanted FAR_NAME_CVARS plateNameStyle`, every hit read.)
- Players: those with Enable Style off in CineMode on Forever get the game's own plate scaling back (yours). Nobody's saved settings change.
- Other features: UpdatePlates and Options.lua's Name Style page (FarStepChanged) only hold or let go. PlateParts (Plates/PlateParts.lua ~1026, ~1129) is the gate copied.
- Other addons: none.
- Tests that encode it: Tools/offline/farnamesmatrix.lua (styleGeneral on by default there: unchanged, 64 cells kept), namescale.lua (stubs FarWanted), namejump.lua, Dev/NameScaleTest.lua (ns.farNamesTestOff, unchanged).

## States (the matrix)
CineMode on/off, the Nameplates page on/off (platesForced), Enable Style on/off, the Style part loaded/left out, Name Style on/off/unset, ns.farNamesTestOff, the client.
Test: Tools/offline/farnamesgatematrix.lua forever
Test: Tools/offline/farnamesgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| far-names-gate | client=forever cine=on plates=on styleGeneral=off nameStyle=on testOff=no | held=true min=1 | held=false min=0.8 |
| far-names-gate | client=forever cine=on plates=on module=out nameStyle=on testOff=no | held=true min=1 | held=false min=0.8 |
| far-names-gate | client=forever cine=on plates=on styleGeneral=on module=loaded nameStyle=unset testOff=no | held=false min=0.8 | held=true min=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/farnamesmatrix.lua (uncommitted, card 2026-11-23-far-names-step.md) | pin `client=forever cine=on style=on plates=on place=outside fight=no` | held=true (the test leaves Enable Style off, a fresh install's db.styleGeneral false; its "style" dim sets Name Style only) | held=false: no names are drawn there, so nothing to hold. Proposed: the test's style=on also sets db.styleGeneral = true, keeping the pin as meant ("names styled") | PENDING the user's OK |

## Risk
low: Forever players in CineMode with Enable Style off or the Style part left out (their plates scale with distance again, as the game does); a never-set Name Style is moot in game (saved settings carry its default). Pinned offline: 96 cells both clients, only the 3 above change; farnamesmatrix: its other 31 cells and retail's 32 unchanged, its one held cell changes (above). Not proven offline: the plate pass picking the change up live after flipping Enable Style (it settles on the pass's timer, like Name Style itself).
