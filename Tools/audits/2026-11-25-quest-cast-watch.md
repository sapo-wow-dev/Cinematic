# Quest Vision: a spell cast reads nothing with no item quest in the log (fix card)
Fix: every spell you cast read up to five units' names, GUIDs and quest-mob answers (tooltips), the quest
log's item quests and their objectives, and formatted two debug lines, even with nothing it could find
Found by: audit 2026-11-25 (gating, finding D19 in 2026-11-25-gating-findings.md)
Code: Visions/QuestMobs.lua: castWatcher's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: each UNIT_SPELLCAST_SENT ran AimedAt (ns.IsQuestMob on target, soft target, mouseover, focus:
  tooltip reads), ItemQuests and each item quest's objectives, and built "cast ... sent at ..." strings
  printed only under /cine debug questitem. Same at SUCCEEDED.
- After: with no quest in your log that has an item to use (the only case where a cast can mark an NPC
  done), a cast reads nothing. The debug strings are built only while /cine debug questitem is on. With an
  item quest, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsQuestMob ItemQuests questItemDebug`)
- Players: the "!" going off an NPC you used the item on: unchanged (needs an item quest, read as before).
- Other features: ns.IsQuestMob's spent answer is also read by Effects.lua's Quest mobs plate row,
  PlateParts.lua's plate level and TooltipParts.lua's No wait: with Quest Vision off too. So the watcher is
  NOT gated on Quest Vision (the finding's suggestion): that would bring back the "!" on spent NPCs for those
  with Quest Vision off. It's gated on what makes the work useless: no item quest.
- Other addons: none.
- Tests that encode it: none on the cast watcher.

## States (the matrix)
Quest Vision on or off; an item quest in the log or none; a cast at your target.
Test: Tools/offline/questcastmatrix.lua forever
Test: Tools/offline/questcastmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| quest-cast-watch | itemQuest=no | looked=yes | looked=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the item quest list is the one the cast used already (kept till the quest log changes). Left as it
was: with an item quest in the log and Quest Vision off, casts still do the work (for the other readers
above). Not proven in game: a real item quest's NPC losing its "!".
