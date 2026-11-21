---
name: error
description: The user typed /error. Read the addon's saved log (SavedVariables) for the latest errors, find the cause in the code, and fix it.
argument-hint: "[how many sessions back, default 5] [what they were doing]"
---

The user hit an error in game and wants it looked at without pasting the log.

1. Run, from the repo root (first argument, if a number, is how many sessions back to look; default 5):

   ```
   python -I .claude/skills/error/recent_errors.py <sessions>
   ```

   It picks the most recently saved CinematicDev.lua / Cinematic.lua across the WoW clients, prints each `ERROR:` with its session, a few log lines before it, and its stack, plus `errors: Nx` repeat counts and any crash reports from the last day.

2. The game only writes the log on /reload or logout. If the "saved" time is older than the user's error (or no error shows up), tell them to /reload and run /error again, rather than guessing.

3. Focus on the newest error. Older ones from earlier sessions that did not repeat later are often mid-edit states from parallel sessions: check whether the line still looks like that before chasing them, and say so briefly.

4. Read the code at the stack's lines, find the cause (who passed what), fix it, then run luacheck and `~/bin/luacompile.py` on the changed files as usual. Errors raised inside Blizzard files: look at our frame in the stack (pcall, hooks) to see what we did to cause it.

5. Any other words after /error are what the user was doing when it happened: use them to narrow it down. An error during a test: `python -I .claude/skills/test/read_log.py <test key>` shows that test's log with its context and state lines (combat, zone, addons) around the error. A test-kit test's own Lua error is its `verdict FAIL Lua error in the test` line, with the stack.

6. A cause that rests on what the game does (a secret value, a blocked call, combat lockdown): check `python -I .claude/skills/test/known.py <call>` first. Not known: the fix comes with one test-kit test that proves it (the /test skill), never a guessed fix and "try it".

Don't commit; report the cause, the fix, and how to check it in game.
