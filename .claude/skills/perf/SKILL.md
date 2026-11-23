---
name: perf
description: The user typed /perf, or asked to check the profiler, find what makes Cinematic slow, spiky or heavy on memory, or push its performance. Runs the profiler analyzer (Tools/perf/analyze.py) over every saved recording, then takes its time - reads each top hotspot's code in full (one subagent per hotspot), finds the root cause, and comes back with the biggest issues ranked by what they'd save, each with a concrete fix, its risk and its test. Fixes only after the user's OK.
argument-hint: "[client] | fix <n> | record"
---

Goal: **push Cinematic's cost as low as it goes** without losing a feature.
The user wants the few biggest wins, explained plainly, with fixes that hold
up: not a list of every row in the profiler.

Units: always **ms a frame** (and KB a second for garbage), never % (higher
fps inflates %). "Real" cost = the game's figure minus the profiler's own
wrapper cost (deep runs wrap every ns function, ~1.5 µs a call).

## 0. Benchmarks before recordings

The user (2026-11-22): "getting tired of all these 2 min tests that turn out
wrong". So a question about a known hot function is answered by
`/cine debug perf` (Dev/PerfTest.lua), not a 2-minute profiler run: it puts
the game in the state itself (CineMode, a quest shown alone...) and times
the real code there, one call a frame x 60, exact garbage per call, with the
timed parts. About a minute, nothing to do. `python Tools/perf/analyze.py
--bench` compares each step with its last run on that client: the before
and after of a fix. Add a step to the test for every new hot path you fix
(its setup + Bench), so the fix is proven the same way and stays proven.
Ask for a profiler recording only for what a bench can't set up (a real
fight's mix, many plates in a city, login), and say exactly what to do.

## 1. Gather (no game)

1. `python Tools/perf/analyze.py --all` (saves each new recording to
   Tools/perf/history/, writes Tools/perf/reports/<client>-<date>.md). Read the
   whole report for the newest recording, and the older one(s) for trend.
   The report's "Among your addons" section ranks Cinematic among the
   addons loaded with it by the game's own figures (session average and
   worst frame, ms), saved with the recording. Lead with that place when
   telling the user where Cinematic stands. If it says both Cinematic and
   CinematicDev were running, the recording counts Cinematic twice: ask for
   one with only one copy enabled before trusting the totals.
2. Read `Tools/perf/ledger.md`: past fixes, what each saved, leads still open,
   ideas already ruled out (don't suggest those again).
3. Read memory `cpu-profiling.md` (the older hand-written history).
4. Check the recording is of the current code: the run's date (report title)
   is after the last edits to the files in the top issues (`git log -1
   --format=%ci -- <file>` and `git status`). If the code changed since, say
   so: its numbers may be stale.

**Deep vs normal runs.** A deep run wraps every ns function (~1.5 µs a
call), so a loop calling ns functions per row (the combat list's ~300 rows,
the frames pass's ~170 entries) reads several times its real cost, spikes
included (2026-11-22: "rows' rules" 1.4 ms was ~1.35 ms of wrappers). Deep
finds WHERE; a normal run (`/cine profiler 120`) says HOW MUCH. Confirm a
spike or a per-row cost with a normal run before fixing it.

## 2. Pick what to dig into

From "Biggest issues", take the top issues (up to 6) that matter **in play**:
fights, moving the mouse, cities with plates. Skip a row that is the
profiler's own (wrapper cost) or a duplicate (`X` and `ns.X` are one call).
"One-off long calls" only count if they land in play (a fight, every zone
change, every login): say which.

Kinds (from the analyzer):
- **steady**: ms every frame. Saving here lowers the average the user sees.
- **hitch**: each call over 1 ms; the frames-over-5-ms count. These are what
  "spiky" means.
- **spike**: a rare branch far above its average.
- **hidden**: a slow call whose timed parts don't explain it. Its local
  helpers aren't timed. The first fix is to **time them** (ns.ProfileName or
  ns.Profiled around the locals the report lists), not to guess.
- **garbage**: KB a second. Garbage costs later, in collection steps.
- **chatty**: tiny calls made many times a frame. Cache per frame or per event.
- **unwrapped**: time the game counts that no timer names.
- **regression**: grew against the last recording of the same kind.

## 3. Dig (take the time)

One subagent per picked issue, **in parallel, one message**
(subagent_type general-purpose). Each brief carries: the issue's report block
verbatim, the file:line, the run's state line, and this task:

> Read <function> at <file:line> in full, and every function it calls that
> runs on the hot path (follow ns.X and local helpers, across files). Find
> what makes it cost <the figure>: which loop, call or branch, over what list,
> how often, and what triggers the slow path. Check what the game API calls
> cost and whether they make tables. Then propose up to 3 concrete changes,
> each with: the exact code change (a short sketch), the expected saving in
> ms a frame / ms a call / KB a second (show the arithmetic from the
> figures), what could break (stale caches, secret values in fights on
> Forever/retail, combat lockdown, a setting change not picked up, other
> addons), and how to test it (an offline test in Tools/offline/ or a
> self-running /cine debug test). Read Tools/engine/rules/ for game rules
> first. Say what you could not confirm. Do not edit any file.

Then **check each answer yourself** before reporting it: open the code it
cites, check the saving arithmetic, and look for the break it might miss. A
cache needs an invalidation for every input; a "skip when unchanged" needs
every input in the key. Drop a suggestion that doesn't hold up, and say so.

## 4. Report back

Plain, short, ranked by **saving per effort**:

```
Now: <real ms a frame>, <KB/s>, <frames over 5 ms %> (<recording kind, date>)
vs last of this kind: <change>

1. <Name>: <cost now, in play terms> - cause: <one line, file:line>
   Fix: <one line>. Saves ~<x> ms a frame / <y> spikes. Risk: <low/med + why>.
2. ...

To time first: <hidden-time issues: which helpers get a timer>.
Missing recordings: <kinds not recorded yet, from the report>.
```

Then the next step box: which fix(es) to do. Never edit before the OK.

## 5. Fix (after the OK)

- One fix at a time, each with its test (memory: test every code change):
  offline in Tools/offline/ where it can be, else extend a kit test
  (ns.TestKit.Define, reuse an existing test first).
- `luacheck .` after Lua edits; offline checks (`python Tools/offline/run.py`).
- Timers added only to find a cause (ns.ProfileName on locals) may stay: they
  cost nothing while not profiling.
- Ledger: add a line to Tools/perf/ledger.md per fix: date, what, expected
  saving, commit, then the measured result after the next recording.
- Hand over **one** command for the user to re-measure, starting with
  `/reload` if code changed: `/cine debug perf` when a bench step covers the
  fix (add one if none does), else a recording:

```
/reload
```
```
/cine profiler 120 deep
```

  and say what to do during it in one line (e.g. "fight a few mobs in a
  city"), picking the kind of recording that proves the fix (and, if it
  fits, a kind still missing).

## 6. After a re-measure

Run the analyzer again: it compares against the last recording of the same
kind. Put the measured result in the ledger next to the expected one. If a
fix saved much less than expected, say so and why (the arithmetic was wrong,
or the cost moved elsewhere).
