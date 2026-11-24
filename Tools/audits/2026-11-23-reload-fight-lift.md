# Reload: windows reopen when the fight's restriction lifts (fix card)
Fix: after a /reload in a fight, the windows and bags that were open waited for PLAYER_REGEN_ENABLED only; if the
game's combat restriction (C_RestrictedActions, Combat) was still on at that moment and lifted a moment later,
nothing opened until the end of the next fight. And "Windows you have open reopen" turned off during the fight still
opened them at its end.
Found by: release review v2.1.28 (5dec857)
Code: QoL/Reload.lua: fightWait's OnEvent (now OpenAfterFight), Restore
Clients: both
Base: 4d01a3a

## Before / after
- Before: REGEN_ENABLED with the restriction still on: returned, still waiting; the restriction lifting fired nothing
  we heard, so the windows opened at the next fight's end (or never). Tick turned off in the fight: opened anyway.
- After: ADDON_RESTRICTION_STATE_CHANGED (pcall'd RegisterEvent, as DamageReport.lua / DamageVision.lua) also ends
  the wait, checked 0.2 s later (IsAddOnRestrictionActive answers false during that event's dispatch, Forever API
  docs). The tick read again at the fight's end: off = nothing opens and the wait ends.

## Who relies on the old behavior
(`python -I Tools/audit.py refs FightLocked afterFight reloadKeepWindows ADDON_RESTRICTION_STATE_CHANGED`, read every hit.)
- Players: anyone who /reloads in a fight with reloadKeepWindows on. Nobody wants the windows a fight late.
- Other features: the settings window's restore (ns.OpenOptions, its own fight path) untouched; calm reloads
  unchanged (opened at once).
- Other addons: none.
- Tests that encode it: Tools/offline/reload.lua (the fight checks, restriction tied to the fight: unchanged, pass);
  engine rule forever.bags-panels.smartnav-frameshown-combat (works: "wait for PLAYER_REGEN_ENABLED with the combat
  restriction off": still true, now also on its lifting); Tools/errors/known.lua reload-restore-in-fight.

## States (the matrix)
reloadIn (fight / calm) x lift (with REGEN_ENABLED / late, by ADDON_RESTRICTION_STATE_CHANGED) x keep (on /
turned off in the fight), then a next fight, per client.
Test: Tools/offline/reloadfightmatrix.lua forever
Test: Tools/offline/reloadfightmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| reload-fight-lift | reloadIn=fight lift=late keep=on | reload=0 regen=0 lift=0 next=2 | reload=0 regen=0 lift=2 next=0 |
| reload-fight-lift | reloadIn=fight lift=late keep=turnedoff | reload=0 regen=0 lift=0 next=2 | reload=0 regen=0 lift=0 next=0 |
| reload-fight-lift | reloadIn=fight lift=withregen keep=turnedoff | reload=0 regen=2 lift=0 next=0 | reload=0 regen=0 lift=0 next=0 |
| reload-fight-lift-retail | reloadIn=fight lift=late keep=on | reload=0 regen=0 lift=0 next=2 | reload=0 regen=0 lift=2 next=0 |
| reload-fight-lift-retail | reloadIn=fight lift=late keep=turnedoff | reload=0 regen=0 lift=0 next=2 | reload=0 regen=0 lift=0 next=0 |
| reload-fight-lift-retail | reloadIn=fight lift=withregen keep=turnedoff | reload=0 regen=2 lift=0 next=0 | reload=0 regen=0 lift=0 next=0 |

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a reload in a fight with reloadKeepWindows on; 8 cells per client pinned, 5 unchanged on each. Not proven
offline: that Forever really lifts the Combat restriction after PLAYER_REGEN_ENABLED (the lag Damage Vision waits
for), and that 0.2 s after ADDON_RESTRICTION_STATE_CHANGED IsAddOnRestrictionActive answers false; the event also
fires as the restriction comes on (before it's active): checked 0.2 s later, it's then active and the wait goes on.
