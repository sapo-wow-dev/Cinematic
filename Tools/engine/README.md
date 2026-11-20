# Engine rules

What the game engine does, as found by our tests: one entry per rule, with the test that showed it. It's the base for
answering "would this work?" before writing code, and (later) for making the offline stand-in (`Tools/offline/wow.lua`)
act like the real clients.

Not packaged (`.pkgmeta` leaves `Tools` out).

- `rules.lua`: loads every area file and hands back one list (`dofile("Tools/engine/rules.lua")`).
- `rules/<area>.lua`: each returns a list of rules.
  - `secrets-combat.lua`: secret values, combat lockdown, protected/forbidden frames, taint, blocked calls, chat sends.
  - `nameplates-units.lua`: nameplates, unit reads, auras, raid markers, combat log, damage meter, bosses, quests.
  - `camera-movement.lua`: camera CVars and calls, ActionCam, Skyriding, movement, soft targeting.
  - `ui-frames.lua`: frames, fonts, textures, CVars, minimap, chat frames, tooltips, Edit Mode, Settings, gamepad,
    files and /reload, Lua 5.1 traps, which client is which.
- Check: `python -I Tools/offline/run.py Tools/offline/enginerules.lua` (fields, ids, values). Run it after editing.
- `/cine debug rulecheck` (Dev/RuleCheckTest.lua, dev copy): one in-game run that re-tests the rules whose findings
  disagree or never named the client; its RESULT lines (CinematicDB.ruleCheckLog) are keyed by rule id. Offline
  check: `Tools/offline/rulecheck.lua`.

## A rule

```lua
{
  id = "forever.unitpower.mana-secret",  -- unique; <client>.<thing>.<what>, client = all when on every client
  area = "secrets",                        -- free short word for grouping
  clients = { "forever" },                 -- any of: forever, retail, classic_era (all three = every client)
  api = { "UnitPower" },                   -- game calls, frames, CVars or events it's about (searchable)
  when = "always",                         -- when it holds: always, in combat, out of combat, in dungeons...
  rule = "UnitPower(unit, mana) is a secret value even out of combat: comparing it or doing math on it errors.",
  works = { "StatusBar:SetValue(secret)" },  -- optional: what does work (the way around it)
  fails = { "value > 0", "value / max" },    -- optional: what was tried and fails
  status = "tested",                       -- tested | inferred | unknown | changed (the game changed it since)
  tested = "2026-11-09",                   -- date of the last test that showed it (nil for inferred/unknown)
  proof = "/cine debug lowmana",           -- the test, command or log that showed it
  source = "memory: forever-mana-secret",  -- where the finding was written down first
}
```

Rules say what the game does, not what Cinematic chose to do about it. "Tested" means a run in game showed it on that
client; anything not in here is unknown, never fine. When a new test disagrees, update the rule (date, proof) and set
`status = "changed"` with the old behavior in `rule` if the game changed, rather than adding a second rule.

Clients: Forever = game 16001 (the user's main test client), retail = mainline, classic_era = game 11509.
