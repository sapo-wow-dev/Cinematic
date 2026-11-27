# Simulation recorder and replay bench: plan

Draft 2026-11-27, not agreed yet. Goal: see the whole addon working together
in real situations, measured, so the engine redesign (every job on the
cheapest of three engines: on an event, on a timed loop, on every frame) is
decided from numbers, not from reading code.

## Why

- The in-game profiler (`Profiler.lua`, `/cine debug cpu`,
  `Tools/perf/analyze.py`) gives real milliseconds, but every run is
  different (frame rate, players around, other addons), and the ledger has
  two baselines, both "CineMode, calm, solo". Cities, fights and flying were
  never measured.
- The offline stand-in (`Tools/offline/wow.lua`, 360 lines) loads the whole
  addon, but has no clock (`GetTime` is 0), runs no OnUpdates, fires no
  timers, and has no units, plates or chat. Tests fake one thing at a time
  by hand (`fightsfades.lua`, `calmplatesmatrix.lua`, `idletick.lua`).
- So nothing today can answer: in a busy city, what runs, how often, and
  what set it off?

## The parts

| Part | Where | What |
|---|---|---|
| 1. Recorder | `Tools/sim/recorder/` (an addon of its own) | Records what the game sends and what it would answer, while you play |
| 2. Converter | `Tools/sim/convert.py` | Turns a recording in SavedVariables into a scenario file, names hidden |
| 3. Replay bench | `Tools/sim/replay.lua`, on `Tools/offline/wow.lua` | Plays a scenario through Cinematic on the stand-in: clock, frames, timers, events, a world to ask |
| 4. Report | `Tools/sim/report.py` | Per scenario: what ran, how often, set off by what |
| 5. Calibration | in game + bench | The same scenario measured both ways; counts must agree |

None of it ships: `.pkgmeta` leaves `Tools/` out.

## 1. Recorder

A small addon of its own (`CinematicRecorder`), not part of Cinematic.
Cinematic changes the game while it runs (in CineMode it switches every
nameplate on, so more plate events fire); a separate recorder can record with
Cinematic on or off, and says which.

Only watches: `RegisterAllEvents` and reads. It never replaces or wraps a
game function (that would taint the UI).

Recorded:

- **Events:** every event with its arguments and time. The combat log through
  `CombatLogGetCurrentEventInfo`.
- **Snapshots:** the state Cinematic asks about, on each event and every few
  frames, as changes from the last snapshot:
  - units: player, pet, target, focus, mouseover, party/raid, every
    nameplate unit: GUID, name, level, class, reaction, health, power,
    auras, casting, in combat, dead
  - you: in combat, moving, mounted, flying, on a taxi, resting, zone and
    subzone, instance type, group
  - the screen: cursor position, mouse buttons and modifier keys, which game
    windows are shown, chat input open
- **Frame times:** each frame's length, so the replay can run at the real
  frame rate.
- **A header:** client and build, date, length, average frame rate, whether
  Cinematic was loaded, its profile and CineMode state, and a note you type.

Secret values (fights on retail and Forever) are recorded as "secret", so the
replay hands back secret values in the same places.

Names and chat: other players' names, guilds and pets become stand-ins
(`Player17`, the same one each time), chat text becomes `x`es of the same
length. Your own character becomes `You`. Rates and timing stay; content
goes. (Done in the converter, so a raw recording never leaves your machine.)

Use: `/simrec start <name>`, `/simrec mark <text>` (a line in the recording,
"pull starts"), `/simrec stop`. `/reload` or log out to write it.

Limits: SavedVariables are written only on reload or logout, and a dungeon
pull's combat log can be thousands of lines a second. Recordings stay short
(30-120 s), and the recorder stops itself past a size cap and says so.

## 2. Scenario files

`Tools/sim/scenarios/<name>-<client>.lua`, one table, made by the converter:

- `header`: as above
- `units`: id -> the unit's lasting facts (name stand-in, class, level...)
- `frames`: frame lengths
- `stream`: in time order, each entry an event (`t, event, args...`) or a
  snapshot change (`t, unit, field, value`)

Committed (no names, no chat), so every check run can use them.

## 3. Replay bench

Extends the stand-in. What it adds:

- **Clock:** `GetTime`, `debugprofilestop`, `time` move with the scenario.
- **Frame driver:** each recorded frame, OnUpdate on every *shown* frame
  (the game runs none on hidden ones), in the order they were set.
- **Timers:** `C_Timer.After`, `NewTimer`, `NewTicker` fire when due.
- **Events:** sent from the stream at their times, to frames registered for
  them, `RegisterUnitEvent` filters applied.
- **World:** the unit and player state from the snapshots; the game
  functions Cinematic calls answer from it (`UnitHealth`, `UnitExists`,
  `InCombatLockdown`, `C_NamePlate.GetNamePlates`, `GetCursorPosition`...).
- **Plates:** a plate frame per nameplate unit, made and taken away with
  `NAME_PLATE_UNIT_ADDED/REMOVED`.
- **Asked, not modelled:** every game function Cinematic calls that the bench
  doesn't answer from the world is counted and listed. That list says what
  to model next, and a scenario with an important one on it isn't trusted.

## 4. Report

Per scenario, for the whole run and per second:

- OnUpdates active per frame, by who set them (the loop labels
  `Diagnostics.lua` already keeps)
- runs of each job (the `ns.Profiled` names), and what set each run off:
  an event (which), a timer, a frame
- event handler calls per event
- calls into the game, by function (`SetAlpha`, `SetCVar`, plate calls...)
- timers made
- the asked-not-modelled list

Kept as `Tools/sim/baseline-<scenario>.txt`, so a change shows as a diff.
Once the engine redesign sets targets ("standing still in a city: no
per-frame loop"), they become checks that fail.

## 5. Calibration

Each scenario recorded once with Cinematic's profiler on as well. The
profiler counts calls per section; the bench counts the same sections. Where
the counts disagree by more than a few percent, the bench is wrong and gets
fixed before its numbers are used. A scenario that hasn't passed this isn't
used for decisions.

## Scenarios

| Name | What you do | Length |
|---|---|---|
| city-still | Stand in a busy capital: plates, crowds, chat | 60 s |
| city-walk | Walk through it | 60 s |
| quest-solo | Open-world questing, a few solo fights | 120 s |
| dungeon-pull | One group pull, start to finish | 60 s |
| flight | Mount and fly across a zone | 90 s |
| city-still-off | city-still with Cinematic switched off (the game alone) | 60 s |

Forever first. Retail next, for secret values and its newer events.

## What it won't do

- Real milliseconds: the stand-in isn't the game. Time comes from the
  in-game profiler; the bench counts work.
- The game's own side: Blizzard's frames reacting, the plate system,
  drawing. Calls into the game are counted, not run.
- Taint and protected frames: nothing is protected on the stand-in.

## Steps

1. **Probe** (one in-game run, `/test`): on Forever and retail,
   `RegisterAllEvents` and its cost, the combat log on Forever, how big
   60 s in a city is, what reads as secret in a fight. Engine rules for the
   answers.
2. **Recorder** and **converter**: the six scenarios recorded on Forever.
3. **Clock, frame driver, timers** on the stand-in: Cinematic runs a
   recorded minute with no world (everything asked is listed).
4. **World and plates** from the snapshots, the asked-not-modelled list
   worked down.
5. **Report** and baselines.
6. **Calibration** of every scenario.
7. **Use:** the measured map of the whole addon (every job, its engine now,
   its trigger, its cost) and the shared-state table (who writes and reads
   `ns.lastCinematic`, `ns.framesWake`, `ns.scene`...) for the engine
   redesign plan.

## Open questions

- Does Forever have `RegisterAllEvents` and `CombatLogGetCurrentEventInfo`?
  (Step 1.)
- Record with Cinematic on, off, or both for each scenario? (Both for
  city-still; on for the rest, its profile noted.)
- The bench on both offline runtimes (`lua5.1` and `run.py`'s lupa), or one?
