# Other addons: Questie's support gated (fix card)
Fix: with Questie not installed, or its support switched off on the Addons page, our tooltip pass, No wait for list, quest item button and target mark still reached into Questie's support (a table and a closure per tooltip with no Questie).
Found by: audit 2026-11-22 (retroactive card, 2026-11-23)
Code: UI/TooltipParts.lua: LinesToCut(), SkipsWait(); Visions/QuestItemButton.lua: ns.RefreshQuestItemButton(); Visions/QuestMobs.lua: ns.RefreshTargetQuestIcon(); AddonSupport.lua: ns.AddonUp() (reads the Addons page box)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: without Questie, every mob tooltip, the item button and the target mark still asked Questie's support code
  (nothing showed wrong, it cost garbage). With Questie's support unticked on the Addons page and reloaded, only its
  setup stopped: our tooltip lines, item button and target mark still followed Questie.
- After: none of that runs without Questie, or with its support off. ns.AddonUp says no for any addon whose support
  box is off (all supported addons, not only Questie), read live (bdb2e1d), at login since ae2cda8.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AddonUp addonSupportOff ForgetAddonSupportAtLoad`)
- Players: anyone with Questie and its support unticked (Addons page): Questie's own target icon we'd hidden was
  left hidden till the reload after bdb2e1d (fixed by ae2cda8, card 2026-11-23-addons-support-box-reload.md).
- Other features: every ns.AddonUp caller now follows the box for its addon: plate quest icons (Plates/PlateParts.lua
  1558, 3246, 3681), plate fade (Effects.lua 970), guild/giver names (Plates/PlateGuild.lua 461, Visions/QuestGlow.lua
  1262), Questie minimap reveal (Support/QuestieMinimap.lua, UI/NodeSweep.lua), QuestTrackerOfAddonUp.
- Other addons: Support/Questie.lua's ns.Questie* functions.
- Tests that encode it: Tools/offline/questiegate.lua checks 1-2, Tools/offline/noaddons.lua (late loads),
  memory addon-gate-addonup.md (USER RULE).

## States (the matrix)
Questie (not installed / in at login / loaded late, after login) x its support box (on / off: saved off, after the
reload / unticked this session, no reload yet / ticked back on, no reload yet), per client. Each cell is a fresh
login with a moment of play (a tooltip, the item button, a target) before the box changes.
Test: Tools/offline/questiegatematrix.lua forever
Test: Tools/offline/questiegatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| questie-gate | questie=none | setup=no asks=tip,wait,item,mark | setup=no asks=none |
| questie-gate | questie=login box=off | setup=no asks=tip,wait,item,mark,icon | setup=no asks=none |
| questie-gate | questie=late box=off | setup=no asks=tip,wait,item,mark,icon | setup=no asks=none |

## Found next to it
`audit.py card --new bdb2e1d` shows two cells this commit changed and didn't mean to (reading the box live):
- `questie=login box=unticked`: setup=ran asks=all -> asks=none. Unticking stopped our put-back code too (Questie's
  target icon left hidden, moved plate icons left moved) till the reload. The regression ae2cda8 fixed (its card).
- `questie=late box=unticked`: setup=no asks=all -> asks=none. Wrong before and after by the at-login rule (see
  the 2026-11-23 card's Open).
Running this card against the working tree shows those two plus ae2cda8's cells as UNDECLARED: they're declared in
2026-11-23-addons-support-box-reload.md.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: four call sites gated, the gate in ns.AddonUp. Not proven offline: the plate paths (PlateParts, Effects, guild
names), which follow the same ns.AddonUp; that something calls ns.AddonUp in game before the player can untick the
box (the box is read on the first ask since ae2cda8, not at login: the matrix plays a moment first).
