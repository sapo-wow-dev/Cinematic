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

## Wiki tags (generated)

`python -I Tools/engine/wikiapi.py` reads the Warcraft Wiki's
[World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) page (or a saved `?action=raw` copy given
as its argument) and:

- writes `wiki-api-tags.lua`: every function the wiki tags (protected, nocombat, hwevent, noinstance, noscript,
  grouponly, deprecated) with its tags. Look a call up there before asking "would this work?";
- writes `rules/wiki-tags.lua`: one `inferred`, retail-only rule per tagged call Cinematic's code makes that no
  hand-written rule names in its `api`. Never edit it: when a test shows one, write the rule by hand in its area file
  and the next run drops the generated one;
- prints CHECK lines: hand-written rules naming a tagged call, to compare with the tag.

Run it after a client patch (the wiki's page says which patch it's up to date for). Names and tags only: the wiki's
text is CC BY-SA and none is copied. The tags are retail's; Forever and Classic Era can differ (Forever's ReloadUI is
blocked even from a click). Self-test: `python -I Tools/engine/wikiapi.py --selftest`.

## The game's templates as parts recipes (per client)

`python -I Tools/engine/templates.py` reads each client's code export (`<client>/BlizzardInterfaceCode`) and turns
templates into recipes. It covers every template the addon's code names, the Preview Match plan's, and what they're
built on. Only definitions that load on that client count. Each recipe has:
- kind, size, mixins and scripts, key values, a status bar's fill;
- every part: parentKey or name, layer, atlas or file, size, anchors, hidden, alpha, font;
- child frames as recipes of their own.

Inherited templates are merged in the inherits order, then the template's own XML, the way the game builds it. It
writes `api/templates-<client>.lua`, git-ignored with the rest of `api/`. `--show <Name> [client]` prints one recipe.
`Tools/offline/templateparts.lua` puts these recipes on the offline stand-in (opt-in). The Style Lab uses them too,
with `build.py --game-parts`. Check: `--selftest`.

## The game's own API docs (per client)

The docs behind the game's `/api` command come from either of two places:

- **The game's code export (no game run).** Start the game with `-console`, then at the character screen press
  `` ` `` and type `exportInterfaceFiles code`, once per client and again after a patch. It writes
  `<client>/BlizzardInterfaceCode`.
  - apidocs.py runs its `Blizzard_APIDocumentationGenerated` files, walked by Dev/ApiDocsDump.lua's own code. So the
    lines are the in-game dump's to the letter: on Forever, 2026-11-23, all 9241 lines were the same.
  - It also adds the tables outside any system that the dump never reached (`T - ...`, most Enums with their values)
    and the docs' help sentences (`api/<client>-help.txt`).
- **`/cine debug apidocs`** (Dev/ApiDocsDump.lua, dev copy) saves the same docs for the client you're on into
  `CinematicDB.apiDocs`, then asks for a reload.

Each line is one function, event or table, with every extra field Blizzard puts on an entry kept (secret flags and the
like). `python -I Tools/engine/apidocs.py` reads both for every client, uses the newer one, compares the two when both
are there (lines found only in one are listed), and then:

- writes `api/<client>.txt` (git-ignored: Blizzard's data stays on this PC). Look a call up there for its exact
  arguments and returns on that client;
- prints FLAG lines (each extra field, how many entries carry it), MISSING lines (a rule lists a client whose docs
  lack a call another client has) and RULEFLAGS lines (extra fields on the calls rules name).

`/cine debug apidocs clear` drops the saved copy (it's big). Checks: `python -I Tools/engine/apidocs.py --selftest`
and `python -I Tools/offline/run.py Tools/offline/apidocs.lua`.

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
