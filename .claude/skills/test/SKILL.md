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
   each client's /api docs (Tools/engine/api, if dumped), the game's own UI
   code (`source`: each client's BlizzardInterfaceCode export, file:line and
   whether that file loads on the client), every archived and saved test log,
   the memory notes, the per-feature ledgers, the Dev/ test headers, the plans
   and the commit subjects. `--only rules,logs` narrows it.

   **Read the game's code before planning a probe** about how a Blizzard frame,
   template, mixin or slash command behaves (what it calls, which arguments,
   which parts it has, what fills it): `known.py <name> --only source`, then
   open the files it names in the export and read them in full. For a
   template, `python -I .claude/skills/test/gamesource.py --template <Name>`
   says where it's made, whether it loads, its inherits and mixin, and
   whether anything in its chain makes it secure. The code
   answers what it does; a probe is only for what code can't show (engine
   calls, secret values, timing, what's on screen). Only trust a hit marked
   `[loads]` for that client: one export holds every flavor (Forever is game
   type `camelot`), and a `no:` file never runs there. `?:` means the .toc
   doesn't list it (an .xml may include it: check). No export, or "Wow.exe is
   newer", means ask the user to export again: start the game with `-console`,
   at the character screen press `` ` `` and type `exportInterfaceFiles code`
   (once per client). It's Blizzard's code: read it where it is, never copy it
   into the repo.
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

- the command itself: `/cine debug <name> [full | step numbers | restore]`,
  typed again to stop; `/cine debug kit` lists every kit test. No Slash.lua edit.
- **focused runs** (the user, 2026-11-22: "once we know something works ...
  test just what we need", reload boxes and questions cost the most time):
  see "Prove once, then leave it out" below.
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
| `r:Overlaps(control, page, { its label })` | what a placed control covers on its page: every visible button, tab, box, slider and line of text it overlaps (empty: clear). **Every control you place or move on a settings page gets it**, in game (offline stand-ins have no layout) |
| `r:Proven(what)` | true (logged "proven, not checked again") unless the run is `full`: `if not r:Proven("seen in run 3") then <check or question> end` |
| `r:Log(text)` | anything else worth having |

Never call `Sleep` / `Shot` / `WaitFor` inside a pcall (Lua 5.1 can't yield
across it).

### A menu change: every state the page can be in

A control placed or moved on a settings page is checked in game, by the
test, in **every state that page can be in**, not just the one the change is
about: its part loaded and left out, its switch on and off, tabbed (header
dropped, ns.DropPageHeader) and not, each client. For each: open the page
(`ns.OpenOptions`), `r:Overlaps` on the control, inside the page's width, no
off card over it (`ns.PageOffCardWanted`), a shot behind `SettingsPanel`.
(2026-11-22: Load Style sat on the Themes tab with Style loaded; the tests
only ever opened the page with Style left out. The user: "checking the menu
should be a common step in development".)

### Prove once, then leave it out

Every user action (a Reload click, a "do you see it?" question, a shot to look
at) is paid once. After the log proves it:

- mark it **proven** in the test, with what proved it:
  - a whole step: `proven = "<test> run N: what it showed"` on the step: left
    out of normal runs, the start line names it;
  - one check or question inside a step: `if not r:Proven("...") then ... end`;
  - a test over many parts or rows (loadparts' `PARTS`): `proven` per entry,
    the run takes only the unproven ones, so a new part is tested alone.
- A step or check can be proven only by a PASS in a real log. A FAIL, a SKIP,
  or a check whose code changed since loses its mark: unmark it on the change.
- A normal `/cine debug <name>` then runs only what's new: hand that over while
  working. The ledger says what is proven and by which run.
- **One full run at the end**, before the commit (or release) the work goes in:
  `/cine debug <name> full` runs every step and check, proven or not. Say in
  the hand-over that it's the full one.
- Grow a test by adding the new checks as unproven, never by making the user
  sit through the old ones again.

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
Count the user's actions: everything proven costs none (leave it out). Then
hand it over through the **test queue** (below). Log the run in the ledger.

### Hand over through the test queue

Several sessions work at once; each queues its kit test instead of handing the
user a command, and the user runs them all from one click
(`Dev/TestQueue.lua`, `Tools/testqueue.py`):

```
python -I Tools/testqueue.py add <test> [steps | full] --session "<this session's short name>" --note "<what it checks>" [--needs "<where to be / what to have>"]
python -I Tools/testqueue.py wait <id>      (run_in_background: it ends when the game saved the result)
```

- The game shows a picker: queued tests first, then every kit test, each with
  Hands off / Needs you and what it asks (scanned from the test's
  r:WaitFor / r:Prompt / r:Click words). A wait with no words that still needs
  the user (a fight, a place) can't be seen: give the test `needs = "..."`
  in its Define, or `--needs` here. The user checks groups (Hands off, Needs
  me) and runs them.
- **Report issue**: the user can flag a test while it runs (the button on
  every step's row, and on the older-test strip): the test, its step, what
  it asked, and their message. `wait` prints each as `ISSUE the user
  reported (client, step): ...` and exits 1 even on a clean result; the
  test's log has an `ISSUE reported by you at step ...` line where it
  happened. Treat it as a FAIL of that step: answer it before anything else.
- Which client: `--client forever | retail | both` (default: either, the
  first client that runs it). Each client's picker runs only its own and
  lists the rest under "Waiting for ..."; `wait` holds until every client
  asked for has saved a result. `testqueue.py list --client retail` is what
  retail still owes. A fix for one client that must not change the other:
  queue it `--client both`.
- Kit tests and older tests (Dev/TestKitWrap.lua's OLD list) can both be
  queued. An older test never says when it's done: the game runs its
  command and the user clicks Done on a strip at the top when its box says
  it's finished; its result is RAN with its PASS / FAIL lines counted, its
  log copied to testQueue_<id>Log like the rest. Give an older test
  `--needs` (the picker can't scan it).
- The reply is then: queued as `<id>`, "/reload, then click Run all" (the box
  offers every session's tests; it also says the box will ask for, if
  anything), and that the results come back on their own after the Reload
  button at the end. No "check log" needed: the background `wait` wakes you.
- **Queued group**: right after `add`, file this session under the sidebar's
  **Queued** group: `mcp__ccd_sidebar__list_groups`, take the id of the group
  named `Queued` (none: `create_group` "Queued"), then
  `mcp__ccd_sidebar__move_sessions` `["self"]` to it (moving "self" asks
  nothing). When `wait` ends (result or timeout), or the entry is removed,
  move "self" back with `section_id: "sessions"` (Ungrouped; `group_id: null`
  fails) before reading the log.
  Several tests queued from one session: move back after the last `wait`.
- When `wait` ends: `read_log.py testQueue_<id>` (it prints the command) is the
  check log for this run, the test's log copied apart under its id, so another
  session running the same test can't take it. `wait` takes the entry off the
  queue; a code change after queuing needs a new `add`.
- **Requeue button (USER RULE, 2026-11-23: "sometimes i just mess it up").**
  Any result that isn't clean (a FAIL, STOPPED, CUT-OFF, DID-NOT-START or a
  reported issue): `wait` prints `requeue: <add command>`. The turn's
  `wrap_up` ALWAYS offers a **Requeue** reply button (first, unless a fix is
  clearly needed first: then "Fix + requeue" first, "Requeue" second). On the
  click, run that exact add command (and a background `wait` on the new id);
  never requeue on your own.
- `list` shows every queued test and result; `remove <id>` or
  `--session "<name>"` takes them off; `/cine debug testqueue` brings the
  offer back in game, `testqueue clear` drops what's waiting.
- Dev/TestQueue.lua and Dev/TestQueueList.lua are in CinematicDev.toc: the
  first time after that line was added, the game needs a restart, not a
  /reload.

## 5. Check log

```
python -I .claude/skills/test/read_log.py <key> [client]
```

**Inspect every error (USER RULE, 2026-11-25).** The kit ends each run with
`errors during the test: N kind(s)` and one line per error that grew: kind,
count, first Cinematic file:line, and `THIS TEST'S FEATURE` or `another
feature` (give the test `files = { "UI/X.lua", ... }` so it can tell). What
fires after DONE until the /reload comes as `errors after the test:` lines.
List every one in the reply with its owner, and get each fixed: here, or
sent to the session that owns it. Never "not this feature" and move on.

Prints the test's log, the session's deverror / BLOCKED / ERROR / chat lines,
the screenshots taken since it started (open every one), the game's own logs
(the console's errors and warnings from the last UI session, saved even
without `-console`, and Logs/FrameXML.log's load errors since the test
started: errors in Blizzard's code and syntax errors show up there, never in
our log; `(game code only)` marks a stack with no Cinematic file, which may
still be ours through taint or a frame we made), and archives the log
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
   Fix all three. Then mark what this log proved as `proven` (step, check or
   part), so the next run doesn't ask for it again.
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
