---
name: test
description: The user typed /test, or a feature or fix needs anything checked in game, or the user says "check log" after a test. Answers "would this work?" from what we already know (engine rules, API docs, past test logs, memory) before any test; when a test is needed, plans ONE wide run that probes every unknown and the questions its own answers will raise; reads the log in full and closes all open questions at once. Aim: probe, build, confirm (three runs or fewer per feature). Keeps a ledger per feature in Tools/tests/.
argument-hint: "[feature or question] | check log [test key]"
---

The user runs several features at once and a test run costs them a /reload, a
trip in game and a reply. **Each run must answer everything it can.** The
failure this skill exists to stop: a log comes back, we find one more thing to
check, hand over another run, and the user ends up testing 100 times.

Target per feature: **run 1 probe (+ first build), run 2 the built feature,
run 3 confirm.** Often fewer: when everything is already known, no probe at
all. More than three means the planning failed. Say so (step 6).

## 0. The ledger

One file per feature: `Tools/tests/<feature>.md` (committed with the feature).
Read it first if it's there: it carries the questions and runs across sessions.

```markdown
# <Feature>: test ledger
Goal: <what the player gets, one line>
Code: <files>

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | UnitPower mana readable out of combat? | forever | NO, secret | rule forever.unitpower.mana-secret |
| Q2 | Curve alpha follows mana in a fight? | forever | open | run 1 step 3 |

## Plan tree (step 3)
Q2 yes -> build the bar on the curve; then need: Q5. Q2 no -> way B (...); then need: Q6. Both probed in run 1.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
```

## 1. Know first (no game)

1. Read the code you'd touch. List every game call, frame, CVar, event and
   state the feature rests on (combat, instance, secret reads, protected
   frames, the client).
2. Look each one up:

   ```
   python -I .claude/skills/test/known.py <call> <frame> <word> ...
   ```

   It searches the engine rules (Tools/engine/rules), the wiki's retail tags,
   each client's /api docs (Tools/engine/api, if dumped), every archived and
   saved test log, the memory notes, the per-feature ledgers, the Dev/ test
   headers, the plans and the commit subjects. `--only rules,logs` narrows it.
3. Write each question into the ledger with its answer:
   - **tested** on that client, still current: settled. Don't test it again.
   - **tested NO**: say it can't work, with the proof, and use the rule's
     `works` way round if it has one. No test, unless a patch since may have
     changed it (then it's one probe line, not a whole run).
   - tested only on the other client, `inferred`, `unknown`, or not found:
     **open**. Not being in the rules means unknown, never fine.
4. A past log contradicts a rule, or two rules disagree: fix the rule now
   (date, proof, `status = "changed"` if the game changed), per
   Tools/engine/README.md, and run
   `python -I Tools/offline/run.py Tools/offline/enginerules.lua`.
5. Nothing open: build it, prove it offline (Tools/offline via run.py), and
   the only run is the confirm run. Tell the user why no probe was needed.

## 2. Widen the net

The user asks about one thing; the run covers its neighbors too. For every
open question, go through this list and add what applies (as probes or steps,
or a line in the ledger saying why it doesn't apply):

- **States**: out of combat, in combat, *after* combat (taint and blocked
  actions often show then), dungeon / raid / city / open world, solo / group,
  mounted, flying, dead.
- **Secret values**: every read the feature makes, in and out of combat
  (Forever makes most fight reads secret). Log type and `issecretvalue`.
- **Protection**: InCombatLockdown, protected / forbidden frames, taint, the
  dev error and BLOCKED counts before and after each step.
- **Clients**: Forever first. Retail only when the user brings it up; a
  retail-only change must not change Forever (or the other way round).
- **Cinematic's own state**: CineMode on and off, the page switch and every
  parent switch (style-switch-chain), defaults on a fresh install, /reload,
  migrations.
- **Other addons** that touch the same frames (Support/), the gamepad.
- **What the user sees**: screenshots of each change, paced.
- **Cost**: ms per frame if it runs in OnUpdate or on every plate.

## 3. Think past the run (the step that saves runs)

Before writing the test, for each open question write its possible answers
(yes / no / secret / errors / nil / something else) and, for each answer:
what you'd build next, and **what you'd then need to know**. Any game fact in
that second list goes into *this* run too. Write the tree in the ledger.

- Two ways might work: build both, test both in the same run (A/B), log
  which won. Don't test way A, learn it fails, then come back for way B.
- The code is cheap to write: run 1 carries the first build behind the probes,
  so run 2 is the finished feature, not a second probe.
- Several features in this session wait on the same game state (one fight,
  one dungeon): one run covers them all.
- Ask: "the log is back and every probe answered. Can I finish the feature
  from it with no further facts?" If no, the run is missing something. Add it.

## 4. Build the run

Build every new test with **the test kit** (`Dev/TestKit.lua`, dev copy; the
example to copy is `Dev/KitCheckTest.lua`). One `ns.TestKit.Define({...})` in
`Dev/<Name>Test.lua` (add it to CinematicDev.toc) gives `/cine debug <name>`
with all the in-game-testing rules already kept, so the test only says its
steps:

- the command itself: `/cine debug <name> [step numbers | restore]`, typed
  again to stop; `/cine debug kit` lists every kit test. No Slash.lua edit.
- the big lasting box per step, no hidden time limit, a DONE box;
- CineMode off for the run, kept off, back after (`cineMode = true` only for
  a test about CineMode);
- `settings = {...}` and `r:Set(key, v)`: the undo saved in
  `CinematicDB.<key>Undo` before the first change, put back at the end, on a
  stop, or at the next login after a /reload mid-run. Anything else to put
  back: `r:Keep(k, v)` + `putBack = function(extra) ... end`;
- the log: a **context line** (version, client, build, zone, instance,
  combat, group, level, class, UI scale, loaded addons, the def's `settings`
  and `cvars`, its own `context`), a **state line** and the dev error /
  BLOCKED counts per step (a blocked action fails the step by itself), the
  verdicts and a summary at the end. The run before stays in `<key>PrevLog`.

Inside a step (each `run = function(r)`, in a coroutine):

| Call | What it does |
|------|--------------|
| `r:Probe(label, fn, ...)` | one fact: `probe <label>: ok= type= secret= value= err= [more=] [rule=]`; label `{ label=, rule="<engine rule id>" }` ties it to a rule |
| `r:Fields(label, { name = fn, ... })` | several reads of one thing in one line, each on its own |
| `r:Verdict(ok, text)`, `r:Pass`, `r:Fail`, `r:Skip(why)` | PASS / FAIL / SKIP lines; make them unable to pass by accident |
| `r:Set(key, v)`, `r:Keep(k, v)` | change a setting / keep own state, undo first |
| `r:WaitFor(text, { events = {...}, filter = fn } or { check = fn })` | asks the user (box), waits for ONE event or a check, no time limit; returns what woke it |
| `r:Prompt(text, sub, seconds, buttons)` | the box without waiting |
| `r:Click(text, fn, label)` | a call the game takes only from your click (SendChatMessage...): a button, `fn(r)` runs **in the click**, returns `ok, ...`. Made straight from a step it runs in a timer's `resume()` and is blocked ("blocked: resume()"; the kit then says so) |
| `buttons = {...}` (WaitFor opts, Prompt, a step's `buttons`) | **buttons, never "type /cine ..."**: answers (`"Yes"`: the wait returns `"button", "Yes"`), `{ label, fn }`, `{ kind = "editmode" }` (opens Edit Mode by a secure click, no taint), `{ kind = "reload" }` (secure /reload; the run picks up at the next step after it). Skip step and Stop are on every step by themselves. A step that needs the player to change a game setting gives the button that opens it. Old tests: `ns.TestKit.ShowButtons(entries)` / `HideButtons()` |
| `r:Sleep(s)`, `r:Shot(label, { behind = frame or {frames} })` | wait; a paced screenshot (1.5 s before, 1.2 s after); `behind` puts a solid background behind the frame(s) the shot is about, for that shot only (`pad`, `color` optional). **Give every shot of a frame or text a `behind`**: it reads far better than against the world |
| `r:Log(text)` | anything else worth having |

Never call `Sleep` / `Shot` / `WaitFor` inside a pcall (Lua 5.1 can't yield
across it).

**Old tests** (written before the kit) are wrapped by `Dev/TestKitWrap.lua`:
their steps stay as tested, but each run gets the kit's context lines, the run
before kept in `<x>PrevLog`, and a closing errors / blocked line at /reload;
tests that write into the main log (`ns.Log("<category>", ...)`) are copied
whole into `CinematicDB.<cmd>KitLog` (read_log.py `<cmd>KitLog`). When an old
test needs real work, rewrite it onto the kit and take its line out of the
`OLD` list. Renaming an old test's start function: change its line too
(`/cine debug kitcheck` step 7 and `Tools/offline/testkitwrap.lua` catch a
missing one).

Before handing it over: luacheck, compile, an offline run through the kit on
the stand-in where it can reach the code (`Tools/offline/testkit.lua` shows
how: pretend timers, `ns.HandleSlash("debug <name>")`, then check the log).
Count the user's actions. Then the reply is only: the one command in its own
block, what the box will ask, that there's no time limit, and "say check
log". Log the run in the ledger.

## 5. Check log

```
python -I .claude/skills/test/read_log.py <key> [client]
```

Prints the test's log, the session's deverror / BLOCKED / ERROR / chat lines,
the screenshots taken since it started (open every one), and archives the log
in Tools/tests/logs/ (git-ignored) so known.py finds it later. With no key it
lists and archives every saved test log. The game writes the file on /reload
or logout only: an old "saved" time means ask for a /reload, don't guess.

Then, in this order:

1. **Rules**: every engine fact the run showed goes into Tools/engine/rules
   (new or updated, date, proof). Run the enginerules check.
2. **Ledger**: answer each question; follow the plan tree to the branch the
   answers picked.
3. **The test itself** (it gets better each log): wrong verdicts and why, values
   you had to guess, what the user would have seen that the test didn't check.
   Fix all three.
4. **Decide**:
   - everything answered: build or finish; the next run is the confirm run.
   - still open: write in the ledger *why this run couldn't answer it* (a
     state never reached, a probe missing, the test's fault). Fix that cause,
     then redo step 3 for **all** open questions together. One run for all.
   - **Never hand over a run that adds one more check** while other things
     that will need checking are known. Find them now.

## 6. The budget

Count runs per feature in the ledger, whatever the command is called.

- Before run 4: stop. Write in the ledger which assumption broke the plan,
  tell the user plainly ("this is run 4 because X; it now also checks Y and
  Z"), and widen the net: more probes, both ways A/B, the states that were
  missed. Sometimes a fourth run is the right call; it is never a surprise.
- A run wasted by the test (a false FAIL, a step that couldn't happen) counts
  too: that's what step 3 of check log is for.

## 7. Done

The ledger ends with every question answered and the runs used. The engine
rules hold every game fact. A memory note only for a lesson about how to work,
not for game facts (those live in the rules). Don't commit unless asked.
