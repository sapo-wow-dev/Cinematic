# Known errors and don'ts

Every error we've traced to its root, and the rule for our code that keeps it from coming back. The engine rules
(`Tools/engine`) say what the game does; this says what **our code must not do** because of it, and how to tell the
error when it shows up again.

Not packaged (`.pkgmeta` leaves `Tools` out).

- `known.lua`: the database, one entry per root cause (not per error line: one cause can show as many lines).
- `errors.py`:
  - `python -I Tools/errors/errors.py match [file]`: which entries an error matches (a pasted error on stdin, or a
    file). `/error` runs it on every error it finds in the log.
  - `python -I Tools/errors/errors.py check [root]`: the don't-checks over our Lua (the pre-commit hook runs it on
    what's staged). A hit = code that does what an entry says never to do.
  - `python -I Tools/errors/errors.py selftest`: fields, ids, every check's regex, and every entry's `example`
    matching that entry only. Run it after editing `known.lua`.
  - `python -I Tools/errors/errors.py list`: one line per entry.

## Workflow (the /error skill)

1. Match the error. **Accepted**: say so in one line, nothing to fix. **Fixed** but seen again: the fix didn't
   hold, a regression; go back to the `why` and find what it missed, don't patch the line. **Open**: keep digging.
2. No match: find the root before any fix. Fill all five `why` parts; a fix that can't name them is a guess.
3. The fix, the new entry (with the error as its `example`) and, where code can show it, a `check` go in the same
   change. Add the engine rule too when the cause is game behavior a test showed.

## An entry

```lua
{
  id = "settings-pick-in-fight-gamepad",   -- unique, short kebab-case
  status = "accepted",                      -- open | fixed | accepted (a game limit we live with)
  title = "Settings opened in a fight: one blocked line per list row (gamepad UI)",
  match = {                                 -- plain substrings over message + stack, case-sensitive
    all = { "SmartNavigation", "SetSecureValue" },  -- every one must be there
    any = { "PickSettingsCategory", "OpenOptions" }, -- optional: at least one
    none = { "..." },                       -- optional: none of these
  },
  why = {                                   -- the root, all five required
    call = "what the game blocked or what errored",
    caller = "which of our functions started it (the frame of ours in the stack)",
    path = "why our code was on that path at all",
    rule = "the game rule behind it",
    pattern = "the shape of our code that let it happen (what the don't forbids)",
  },
  dont = "The rule for our code, one sentence.",
  check = {                                 -- optional: how code shows it (Python regex per code line, comments cut)
    pattern = [[:SelectCategory\(]],
    allow = { "Options.lua", "Dev/" },      -- files or folders where it's the one sanctioned place
  },                                        -- a line can also carry "-- dont-ok: <id>" with a reason
  fix = "what was done, commit",            -- for fixed / accepted
  engine = { "forever.settings...." },      -- engine rule ids (Tools/engine/rules)
  seen = { "2026-11-20", "2026-11-22" },    -- dates it came up
  example = [[a real error text that must match this entry]],
  note = "optional: when it only counts (taintLog on...)",
  source = "memory: settings-open-gamepad-blocked-line",
}
```
