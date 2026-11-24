# Plates: old far-names leftovers cleanup on Forever only (fix card)
Fix: the once-only cleanup of the old far-names set's distances (41 / 5) ran on every client, retail and Classic Era too, where that set never was, and errored where neither C_CVar.GetCVarDefault nor GetCVarDefault exists
Found by: release review 2026-11-23 (v2.1.28)
Code: Effects.lua: ns.plates.FarLeftovers
Clients: both
Base: C:/Users/casal/AppData/Local/Temp/claude/749a148a2801cb3d/c52daf98-75d2-4f7a-b7d0-87b1d7987cf3/scratchpad/prefix-tree (a copy of the worktree before this fix: the uncommitted far-names work, Tools/audits/2026-11-23-far-names-step.md, on 4d01a3a. Once that work is committed, this is its commit)

## Before / after
- Before: on retail and Classic Era, the first plate pass out of a fight put a 41 / 5 nameplateMaxScaleDistance / nameplateMinScaleDistance (live or saved as yours) back to the game's defaults, and set farNamesLeftoversV2. With no defaults API, calling nil raised an error (the plate pass stopped there).
- After: Forever only (not ns.isRetail, not ns.isClassicEra), once, out of a fight, as before. No defaults API: nothing changed, no error (the cleanup still marks itself done). The 41 / 5 set never shipped in a release (c4007ec is after v2.1.27); the author's dev copy had leftovers, so Forever keeps it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FarLeftovers farNamesLeftoversV2`, every hit read.)
- Players: none: 41 / 5 were only ever the dev copy's (Forever). A retail or Era player with their own 41 / 5 keeps it now.
- Other features: FarStepChanged calls it (plate pass, the Name Style page).
- Other addons: none.
- Tests that encode it: Tools/offline/namescale.lua's leftovers check (Forever load: unchanged, passes).

## States (the matrix)
The client, Classic Era (ns.isClassicEra on the Forever load), 41 / 5 live or not, saved as yours or not, in a fight or not, the defaults API (C_CVar's, the global, none).
Test: Tools/offline/farleftoversmatrix.lua forever
Test: Tools/offline/farleftoversmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| far-leftovers | client=forever era=no fight=no api=none | error | * |
| far-leftovers | client=forever era=yes fight=no | * | * |
| far-leftovers-retail | client=retail fight=no | * | * |

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

(ns.plates.FarLeftovers is new since v2.1.27: the uncommitted far-names work, Tools/audits/2026-11-23-far-names-step.md,
cleaning up c4007ec's 41 / 5 set (also after v2.1.27). On v2.1.27 the function doesn't exist, so every cell reads
"error"; all 48 per client arrive, pinned.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: nobody outside the dev copy ever had 41 / 5. Pinned offline: 48 cells a client; Forever's out-of-fight cleanup unchanged where a defaults API exists. Not proven offline: Classic Era itself (the matrix stands it in with ns.isClassicEra on the Forever load).
