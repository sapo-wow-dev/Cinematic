# Rules: npc becomes interacting in saved profiles, backups and old shared strings too (fix card)
Fix: the npc to interacting update (Migrations.lua, ruleNpcInteractingV1) now also covers saved profiles' settings (it read the profile table, not its .settings), profile backups and a deleted profile's backups; a profile string (Profiles/Share.lua) or camera trigger string (Camera/Shots.lua) made before this version has its npc read as interacting. New strings carry npcWord = "target" and keep npc.
Found by: release review v2.1.34, 2026-11-24 (Core area audit; the saved-profile miss found writing its test)
Code: Migrations.lua (ns.NpcWordToInteracting, the step); Profiles/Share.lua (ExportProfile, ReadSharedProfile); Camera/Shots.lua (ExportCameraTrigger, ReadCameraShare)
Clients: both
Base: 22bf938

## Before / after
- Before: a rule saying npc (meaning an NPC's window) in a saved profile other than the live one, in a backup, or in a string shared from v2.1.33 or older kept the word npc, which now means an NPC targeted: switching to that profile, restoring the backup or importing the string changed what the rule did, with no warning.
- After: each comes in as interacting, as the live settings did. Strings made from now on keep npc as written.

## Who relies on the old behavior
- Nobody: 22bf938 isn't released. The dev copy already ran ruleNpcInteractingV1, so its own saved profiles and backups stay as they were.

## States (the matrix)
Where the rule is kept (live, saved profile, backup, deleted profile's backup, profile string, camera trigger string); made before or now. Also Tools/offline/talknames.lua (own export round trip).
Test: Tools/offline/npcwordmatrix.lua forever
Test: Tools/offline/npcwordmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| npc-word-everywhere | place=profile made=before | rule=not npc | rule=not interacting |
| npc-word-everywhere | place=backup made=before | rule=not npc | rule=not interacting |
| npc-word-everywhere | place=deleted made=before | rule=not npc | rule=not interacting |
| npc-word-everywhere | place=string made=before | rule=not npc | rule=not interacting |
| npc-word-everywhere | place=camera made=before | rule=not npc | rule=not interacting |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|

## Risk
low: text rewrite already used for the live settings, on tables the cooldown update already walks; a string from an old version without npcWord is converted once on read. An old Cinematic reading a new string ignores npcWord.
