# Card Vision: a dungeon named like the place at its door gets its Discovered card (fix card)
Fix: Discovered kept places by bare name, so a dungeon and the same-named subzone at its door (Zul'Farrak in Tanaris, Uldaman, Scarlet Monastery, Dire Maul, Stratholme) shared one card
Found by: release review 2026-11-23 (d580b7d)
Code: Visions/CardMoments.lua: Discovered, ZoneEntered
Clients: both
Base: 4d01a3a

## Before / after
- Before: "Discovered: Zul'Farrak" played at the dungeon's door (the game's line for the subzone); going into the dungeon after, its first time, no card ("its card was had before" in the log). The dungeon first: its card, then the subzone's line outside no card.
- After: the dungeon's card is kept by its instance ("instance:209"), the outdoor place by its name: each gets its card once, in either order, within Discovered's 30 s skip or after it. A dungeon seen before still none.

## Who relies on the old behavior
(`python -I Tools/audit.py refs Discovered seen.found cardSeen`, read every hit.)
- Players: cardSeen.found (per character, kept). Dungeons carded before this fix are saved under their bare name, so for them the same-named outdoor place stays skipped (can't be told apart); new ones are kept apart. Their seen.instances is unchanged.
- Other features: Carded (hides the game's line): compares lastFound with the line's place; a dungeon's lastFound is now "instance:..", so its card no longer counts as the outdoor place's (the 5 s shownAt check still does). ns.ForgetDiscovered (Dev/ZoneCardTest.lua) forgets by name: its made-up dungeon is seen before, never carded, so unaffected. AchievementProgress.Discovered still gets the name.
- Other addons: none (DaylightUI's line hider goes by Carded, as above).
- Tests that encode it: discoveronce.lua (check 5 reads found[name] for outdoor places: unchanged), discoverinstance.lua, discoveredline.lua, zonecard*.lua.

## States (the matrix)
The outdoor place's line first or the dungeon first, the other within the 30 s skip or after it, the dungeon new or seen before; the client.
Test: Tools/offline/discoversamenamematrix.lua forever
Test: Tools/offline/discoversamenamematrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| discover-samename | first=outdoor dungeon=new | outdoor=1 instance=0 | outdoor=1 instance=1 |
| discover-samename | first=instance dungeon=new | outdoor=0 instance=1 | outdoor=1 instance=1 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: players going into a dungeon named like the place at its door, its first time, now get its Discovered card (and the outdoor place's after a dungeon first). Characters that had the dungeon's card before this fix keep the outdoor place skipped. Not proven offline: the game's real line and instance reads at Zul'Farrak's door (stand-in events).
