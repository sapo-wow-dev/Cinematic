---
name: error
description: The user typed /error, or pasted an error, blocked line or stack. Read the addon's saved log (SavedVariables) for the latest errors, match each against the known errors (Tools/errors), find the ROOT cause of new ones, and fix them so they can't come back.
argument-hint: "[how many sessions back, default 5] [what they were doing]"
---

The user hit an error in game. The aim is never "make this line go away": it's the root cause, written down in
`Tools/errors/known.lua` with the rule for our code that keeps it from coming back.

1. Get the error. Pasted: save it to a scratch file and run `python -I Tools/errors/errors.py match <file>`. Not
   pasted, from the repo root (first argument, if a number, is how many sessions back; default 5):

   ```
   python -I .claude/skills/error/recent_errors.py <sessions>
   ```

   It picks the most recently saved CinematicDev.lua / Cinematic.lua across the WoW clients, prints each `ERROR:` with
   its session, a few log lines before it, and its stack, plus `errors: Nx` repeat counts and crash reports from the
   last day. Under each one: `KNOWN <id> [status]` with its why and don't, or `NEW`.

2. The game only writes the log on /reload or logout. If the "saved" time is older than the user's error (or no error
   shows up), tell them to /reload and run /error again, rather than guessing.

3. Focus on the newest error. Older ones from earlier sessions that did not repeat later are often mid-edit states
   from parallel sessions: check whether the line still looks like that before chasing them, and say so briefly.

4. By what the match says:
   - **KNOWN, accepted**: a limit we live with. Say so in one line (its `fix` says why), add today to its `seen`, fix
     nothing. If it slipped past something meant to quiet it, that's a bug in the quieting: fix that.
   - **KNOWN, fixed**: a regression. The fix didn't hold, so the `why` missed something. Re-read it against this stack,
     find what's different (another caller, another client, a fight), fix the root and correct the entry's `why`.
     Never just patch the line again.
   - **KNOWN, open**: carry on from its `why`.
   - **NEW**: find the root before writing any fix. Fill all five `why` parts: **call** (what the game blocked or what
     errored), **caller** (our frame in the stack, or the earlier code of ours that set it up), **path** (why our code
     was there at all), **rule** (the game rule behind it), **pattern** (the shape of our code that allowed it). Can't
     name one? Keep reading the code or the Blizzard source. For a rule about the game, check
     `python -I .claude/skills/test/known.py <call>` first. Not known = one test-kit test that proves it (the /test
     skill), never a guessed fix and "try it". Errors raised inside Blizzard files: our frame in the stack (pcall,
     hooks), or what we wrote earlier (taint), is the caller.

5. The fix comes with, in the same change:
   - the entry in `Tools/errors/known.lua` (new, or updated `why`/`fix`/`seen`), with this error as its `example`;
   - a `check` (a regex for the code pattern) wherever code can show the pattern, so the pre-commit hook stops it next
     time. Run `python -I Tools/errors/errors.py check`: every hit gets fixed or marked `-- dont-ok: <id>` with why;
   - a test (an offline Tools/offline/*.lua test with the error's stack where possible, else a /cine debug test);
   - the engine rule (Tools/engine/rules) when a test showed game behavior.
   Then `python -I Tools/errors/errors.py selftest`, luacheck and `~/bin/luacompile.py` on the changed files.

6. Any other words after /error are what the user was doing when it happened: use them to narrow it down. An error
   during a test: `python -I .claude/skills/test/read_log.py <test key>` shows that test's log with its context and
   state lines (combat, zone, addons) around the error. A test-kit test's own Lua error is its
   `verdict FAIL Lua error in the test` line, with the stack.

Don't commit. Report: the entry (known or new) and its root in a line or two, the fix, the don't and its check, and
how it's tested.
