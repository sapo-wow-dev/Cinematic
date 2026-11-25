# Core: the switch tree has the same shape whichever parts load (fix card)
Fix: switches whose master was set inside a part's own code lost it when that part was left out
Found by: audit 2026-11-25 (gating, finding F2 in 2026-11-25-gating-findings.md)
Code: Style/MirrorTimerStyle.lua, Camera/CameraRows.lua, Visions/EmoteVision.lua, Atmosphere/LowHealth.lua,
Atmosphere/ManaVision.lua: each file's ns.SetPageMaster lines, moved above its ns.Module line
Clients: both
Base: baabf86

## Before / after
- Before: with Style left out, the Breath Bar's switch had no master (Standard Frames'); with Cameras out, the
  Scenes, Triggers, Scripts and My Shots pages' had none (Enable Cameras'); with Visions out, Emote Vision's
  Nameplates tab and the Vitals pages' tabs had none. Code going by the tree (ns.PageOn, the sweep, ShowMe, the
  tests) saw a different tree per load: those switches read on through it.
- After: the same masters whichever parts load (data only, no part code runs). Nothing a player sees changes: a
  left-out part's code doesn't run, and its pages aren't shown.

## Who relies on the old behavior
(`python -I Tools/audit.py refs SetPageMaster VITALS_TABS VITALS_MANA_TAB`)
- Players: none.
- Other features: ns.VITALS_TABS, ns.VITALS_HEALTH_TAB and ns.VITALS_MANA_TAB are now set with Visions left out
  too (their DEFAULTS still only with it loaded); no code outside Visions reads them.
- Other addons: none.
- Tests that encode it: Tools/offline/manavision.lua (the Style Mana tab under the Vision's): unchanged.
- Left as they are (they need the part's page built): the Card Vision event tabs' masters ("tabOn:Card:<id>:<part>",
  set as the Cards page builds each event's tabs), and the Cooldown Manager Style page's tab chain (cdmRingStyle and
  the ring's settings under "tabOn:Cooldown Manager Style/look:1", mapped by Options.lua's MapTabContainers as the
  page is built: no page, no chain). Both read off by their own readers (ns.CardPartOff, ns.CdmStyleTabOn +
  ns.StyleLook), so no leak; only the tree's shape differs.

## States (the matrix)
Every part loaded or one left out; each moved switch.
Test: Tools/offline/gatetreematrix.lua forever
Test: Tools/offline/gatetreematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| gate-tree-shape | load=style switch=breathBar | none | handleFrames |
| gate-tree-shape | load=cameras switch=cameraScenes | none | cameraModes |
| gate-tree-shape | load=cameras switch=cameraTriggers | none | cameraModes |
| gate-tree-shape | load=cameras switch=cameraScriptsPage | none | cameraModes |
| gate-tree-shape | load=cameras switch=cameraShots | none | cameraModes |
| gate-tree-shape | load=visions switch=emoteVisionPlates | none | emoteVision |
| gate-tree-shape | load=visions switch=tabOn:Vitals:general | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:Vitals:blizzard | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:Vitals:cinematic | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:Vitals:swirl | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:Vitals:effect | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:VitalsVision:health | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:VitalsVision:mana | none | lowHealth |
| gate-tree-shape | load=visions switch=tabOn:Vitals:mana | none | tabOn:VitalsVision:mana |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: masters only, for switches whose part is left out; with the part loaded the tree is as before (pinned: the
load=all cells unchanged). Not proven in game: nothing to see.
