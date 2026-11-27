# Simulation recorder probe: test ledger
Goal: know, before building the recorder (Tools/sim-plan.md), which of
Cinematic's game settings change what the game sends, whether every event
(the combat log too) can be heard, what a city minute weighs, and what reads
as secret in a fight.
Code: Dev/SimCore.lua (the recorder's core, kept free of Cinematic so it can
move into the recorder addon), Dev/SimProbeTest.lua (`/cine debug simprobe`),
Tools/offline/simprobe.lua (offline proof).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does `frame:RegisterAllEvents()` work, out of combat, with no BLOCKED? | forever | open (used in dev tools, `/cine debug eventtest`, CursorHide's focus probe, never written down) | run 1 step 1 |
| Q2 | Does RegisterAllEvents bring the combat log (`COMBAT_LOG_EVENT_UNFILTERED`) on Forever, and with the blocked popup? Registering it by name is forbidden there | forever | open; by name: NO, blocked, pcall doesn't stop it | rule forever.combatlog.cleu-forbidden; run 1 steps 1, 6 |
| Q3 | Is `CombatLogGetCurrentEventInfo` there and readable (secret?) in a CLEU handler? | forever | open (SelfTest lists it; no result written) | run 1 steps 1, 6 |
| Q4 | Each `ns.cvarSets` setting: on this client (GetCVar not nil)? Takes (reads back)? Does our own SetCVar fire `CVAR_UPDATE`? | forever | open | run 1 step 2 |
| Q5 | Which sets change what the game sends, and which events, by how much | forever | open; expected: plates (`NAME_PLATE_UNIT_ADDED/REMOVED`), soft targeting (`PLAYER_SOFT_*`) | run 1 steps 3-6 |
| Q6 | Do the "change nothing sent" sets (camera follow, zoom, cursor, weather) really change nothing? | forever | open | run 1 step 3 |
| Q7 | A city minute, every send-more setting on: events a second by kind, bytes a minute (events + plate snapshots), the recorder's own ms a second | forever | open | run 1 step 4 |
| Q8 | In a fight: which reads Cinematic makes are secret (player, target, plate units), which events carry secret arguments | forever | partly known (rules forever.unithealth.group-secret, forever.unitpower.mana-secret, forever.unit_aura.payload-secret-in-combat...); a full table per read is open | run 1 step 6 |
| Q9 | Does something set a setting back while Cinematic is paused (a feature loop holding one)? | forever | open | every A/B step: read back each 0.5 s |
| Q10 | SoftTarget settings in a fight | forever, retail | NO: protected, BLOCKED even writing the same value | rule forever.softtarget.cvars-protected-combat: secure sets switched out of fights only |

## Plan tree
- Q1/Q2 (step 1): all events heard and no BLOCKED -> the recorder uses
  RegisterAllEvents (way A). BLOCKED or nothing -> way B: a list of events
  (every event Cinematic's code names, plus the common ones), switched to in
  the same run for the steps after, so run 1 still answers Q5-Q8. Then
  needed: how to get the combat log at all on Forever (the chat tab's |K
  tokens are unreadable: rule forever.combatlog-chat.k-tokens), so the
  recorder records without it there.
- Q3: readable -> recorded; secret -> recorded as secret (the replay hands
  secrets back); missing -> combat log left out on Forever.
- Q4: a set that doesn't take or isn't there -> listed in the recorder's
  settings file as "not on <client>".
- Q5/Q6: each set gets "changes: events..." or "nothing sent"; that's the
  `cvars.lua` mark the plan asks for, and the replay's cut-down rules.
  Unclear (noisy) -> it shows as "unclear" with its counts, and a longer A/B
  of just those is run 2's (with `r:Proven` on the rest).
- Q7: the recorder's size cap and how often it snapshots come from it.
- Q8: the replay's secret list.
- Q9: interference seen -> that setting's result is marked unreliable and the
  holder is named from the log; the recorder (no Cinematic) won't have it.

## Run 1: ready, not run yet (2026-11-27)
Built from a cloud session with the user away, so not queued: the queue file
(Dev/TestQueueList.lua) is local to the user's PC. To run it: pull the
branch, **restart the game** (new files in CinematicDev.toc), then
`/cine debug simprobe` (or queue it from a local session:
`python -I Tools/testqueue.py add simprobe --session sim --needs "a busy city, quest objects or NPCs, mobs"`).
The log is `CinematicDB.simProbeTestLog` (`read_log.py simProbeTest`).

What it asks (Tools/testscan.py): steps 1-3 hands off (about a minute, out of
fights, anywhere); 4 a busy city, stand still about 7 min (10 A/B units, then
the minute weighed); 5 walk slowly among quest objects or NPCs about 2 min;
6 fight about 4 min (mobs one after another or a training dummy).

Proven offline (Tools/offline/simprobe.lua, Forever, retail, and with
RegisterAllEvents blocked): every step runs and passes; the settings that
change what's sent are found and the others aren't; every game setting is
put back and Cinematic resumed. The offline world is made up: it proves the
test's logic, not one game fact.

Learned building it (no game needed):
- Grouping sets by their labels put "Friendly player bars on" (a plate
  setting) with the camera ones; the bulk A/B caught it offline. Sets are
  grouped by their settings' names now (`nameplate*`, `UnitName*` plates;
  `SoftTarget*` soft; combat text, selection circle, find yourself fight).
- The dev copy registers test-only sets ("NPC title test", "Rule check",
  "Plate range test"...): marked dev, not A/B tested.
- 26 plate sets one by one would be 16 minutes standing still: alike ones
  are tested together (Names over heads 13, Instance plates off 3, Plate
  looks 3; Game's numbers on 3, off 3). A bundle that changes what's sent is
  split in run 2, with `r:Proven` on the rest.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
