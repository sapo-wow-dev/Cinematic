# WoW's developer console: what it offers Cinematic's tools

Research only, 2026-11-23. Nothing here is built. These are the sources:
- warcraft.wiki.gg pages (linked inline);
- the local /api dump (`Tools/engine/api/forever.txt`) and the engine rules (`Tools/engine/rules`);
- Forever's own UI export in `C:\Program Files (x86)\World of Warcraft\_forever_\BlizzardInterfaceCode` (1.60.1,
  build 71037), plus Forever's `Logs\` and `WTF\SavedVariables\` folders.

Blizzard's code is read where it sits. None of it is copied into the repo (memory note no-unlicensed-data).

Tags: **[seen]** means read on this PC today. **[rule]** means an engine rule or past test already shows it.
**[wiki]** means a current wiki page says so. **[old]** means the source is old or a forum post. **[?]** means unconfirmed.

## 1. What the console is

- **Turning it on.** Use the `-console` launch argument. In the Battle.net app it's under Settings > Game Settings >
  WoW: Forever > Additional command line arguments. It works the same for retail, a shortcut, or `Wow.exe -console`
  [wiki](https://warcraft.wiki.gg/wiki/Console).
  - No Config.wtf line or CVar is known to turn it on [?]. The CVar page mentions `/console enable` [?, untested].
- **The key.** It's `` ` `` by default.
  - `SetConsoleKey("x")` changes it for the session only, ASCII only. `nil` unbinds it. The key beats every other
    binding, chat typing too, and does nothing without `-console`
    [wiki](https://warcraft.wiki.gg/wiki/API_SetConsoleKey). It's in Forever's /api dump [seen].
- **The window itself.** It's an ordinary Blizzard addon, `Blizzard_Console`, with `DeveloperConsoleMixin` in
  `Blizzard_Console.lua` [seen].
  - It shows `CONSOLE_MESSAGE(message, colorType)` lines from the engine, colored by `Enum.ConsoleColorType`
    (0 default, 3 error, 4 warning, ...).
  - It also shows `SPELL_SCRIPT_ERROR` text and anything `DevTools_AddMessageHandler` sends.
  - It has a filter box, command history and copy to clipboard (it says "N characters copied").
  - The cheat browser button shows on GM clients only.
- **It remembers its last 1000 lines on disk.** `Blizzard_Console.toc` declares
  `## SavedVariablesMachine: Blizzard_Console_SavedVars`, and every message is appended to `messageHistory`. The game
  writes that on /reload and logout to `_forever_\WTF\SavedVariables\Blizzard_Console.lua`. That file was 117 KB today
  [seen]. It's readable offline with lupa, the same way the test logs are.
- **What today's 1061 saved lines held** [seen]:
  - engine startup, account data and CVar load lines (`AccountData_RequestLoad`, `LoadGameCVars...`,
    `CVar 'maxLightCount' failed validation for its initial value`), `LimitedLuaResources: Global capacity for Frame
    changed to 100000` (frame and FontString caps), screen changes (login > charselect), and connection lines;
  - **16 Lua errors with full stacks** (color 3). Every one was `CompactUnitFrame.lua:1557: bad argument #1 to
    'UnitWidgetSet'`, reached from `Blizzard_NamePlateUnitFrame.lua:108` on a mouse camera click. It's a nameplate unit
    frame with no unit, and Blizzard code was the top frame. The console records it even with `scriptErrors` off;
  - **194 `Test CVar test_cameraOverShoulder has been set to 0.02 (default 0.000000)` lines.** The engine logs every
    ActionCam `test_*` write with its value and default;
  - warnings such as `Overlay is disabled. Only internal builds and public China builds have it.`
- **How it differs from chat slash commands.**
  - `/console X` in chat is the same as typing `X` in the console. So is `ConsoleExec("X")` from code
    [wiki](https://warcraft.wiki.gg/wiki/MACRO_console).
  - Some commands work only in the real console window, and some only at the login or character screen.
    `exportInterfaceFiles` is one: through `/console` or after logging in, it says "Unknown command"
    [wiki](https://warcraft.wiki.gg/wiki/Viewing_Blizzard%27s_interface_code).
  - The console also shows engine output that chat never gets.
- **The Logs folder (on with or without the console).** `_forever_\Logs\` already holds these [seen]:
  - `FrameXML.log`: addon load errors with time and file. It held `CinematicDev/Dev/PaceTest.lua:373: 'end' expected`
    from 11-21;
  - `General.log`, which repeats the `[Console]` lines;
  - `taint.log`;
  - `EditMode.log`, the raw Edit Mode layout strings per load;
  - `gx.log`, `cpu.log`, `Hotfix.log`, `QuestCache.log`;
  - `DeveloperLog.log` and `TestSuite.log`, both empty;
  - `AddOnLoad.log` if `addonLoadDebugging 1` is set [wiki, summary only].

## 2. Commands worth knowing

| Command | What it does | Status | Source |
|---|---|---|---|
| `exportInterfaceFiles code` | Writes the game's UI Lua/XML/TOC to `BlizzardInterfaceCode\` next to Wow.exe; only from the login/character screen, in the console window | **[seen]** done today on Forever | [wiki](https://warcraft.wiki.gg/wiki/Viewing_Blizzard%27s_interface_code) |
| `exportInterfaceFiles art` | Writes the UI textures as `.blp` to `BlizzardInterfaceArt\`; the client freezes until it's done | [wiki] + [old] on BLP | same; [forum](https://eu.forums.blizzard.com/en/wow/t/exportinterfacefiles-art/412876) |
| `<cvar> <value>` (= `/console`) | Sets a CVar; typed with no value, the console echoes it [?] | [wiki] | [MACRO console](https://warcraft.wiki.gg/wiki/MACRO_console) |
| `cvar_default <name>` | Puts one CVar back to its default. **With no name it resets every CVar** | [wiki] | [Console variables](https://warcraft.wiki.gg/wiki/Console_variables) |
| `cvar_reset` | Back to first-login settings, every CVar | [old] | [addonstudio](https://addonstudio.org/wiki/WoW:Console_variables) |
| `cvarlist` | Lists every CVar with its value and default | [old] | same |
| `reloadui` | Reloads the UI | [wiki] | MACRO console |
| `gxRestart` | Restarts graphics without a UI reload; Cinematic's Graphics page already has the button (`Options.lua:7784`) | [wiki], in our code | MACRO console |
| `ActionCam <word>` | Our tested words and what each sets | **[rule]** forever.actioncam.console-words; never `ActionCam default` (forever.actioncam.default-garbage) | `Tools/engine/rules` |
| `taintLog 0-5,11` | 1 = blocked actions, 2 = global reads/writes, 3 upvalues / 4 table fields (12.0.0), 5 secret writes (12.0.1); writes `Logs\taint.log` | [wiki], **[rule]** forever.taintlog.* (taintLog 2 makes hooksecurefunc throw nil errors on Forever) | [CVar taintLog](https://warcraft.wiki.gg/wiki/CVar_taintLog) |
| `scriptErrors 1` | Lua error popup | [wiki] | [CVar scriptErrors](https://warcraft.wiki.gg/wiki/CVar_scriptErrors) |
| `addonLoadDebugging 1` | Addon load log to `Logs\AddOnLoad.log` | [?] (from a summary of the full CVar list) | [Complete list](https://warcraft.wiki.gg/wiki/Console_variables/Complete_list) |
| `scriptProfile 1` | Old Lua CPU profiling. Modern clients have `C_AddOnProfiler` (Blizzard_AddOnPerformance uses `GetTopKAddOnsForMetric`, `IsEnabled`) | [old] | [CVar scriptProfile](https://warcraft.wiki.gg/wiki/CVar_scriptProfile) |
| Help and command lists | No `help`/`?` command is confirmed. The live list is `ConsoleGetAllCommands()` (command, help, category, type); `ConsolePrintAllMatchingCommands("part")` prints matches into the console | [seen] in the /api dump, **[rule]** works on both clients | `Tools/engine/api/forever.txt` |
| GM and Reveal commands | `Enum.ConsoleCategory` 8 Gm and 9 Reveal; players get "permission denied" | [wiki] | [Console](https://warcraft.wiki.gg/wiki/Console) |

Debug slash commands are Lua in `Blizzard_ChatFrameBase\Shared\SlashCommands.lua` [seen]. They need no console, but
they're the same family:
- `/etrace` (EVENTTRACE);
- `/tinspect` (TABLEINSPECT);
- `/dump` (DUMP);
- `/fstack` (FRAMESTACK). It's registered in `Mainline\SlashCommandsOverrides.lua`; check whether Forever's `[Family]`
  loads it. In `/fstack`, Shift toggles texture info through `Blizzard_TextureInfoGenerator.lua`, which shows the
  atlas or file of the texture under the mouse.

Not found anywhere (no screenshot, trace, frame-dump or atlas-dump console command is documented): `script`/`run`,
`fontsize`, `timetest`, `showlog`, `clear`. `CONSOLE_CLEAR` exists as an event [?].

## 3. What an addon can reach

Taken from Forever's /api dump and the export [seen], plus our rules:

- **`ConsoleExec(command, addToHistory)`**
  - Flagged `SecretArguments=AllowedWhenUntainted` only, not `IsProtectedFunction`, so it runs from addon code.
  - We use it for ActionCam [rule] and gxRestart.
  - Its effect is limited by what the command does: secure CVars set this way in combat fire ADDON_ACTION_BLOCKED
    ([wiki](https://warcraft.wiki.gg/wiki/API_C_CVar.SetCVar)).
  - `exportInterfaceFiles` isn't reachable (glue screen and console window only).
- **`ConsoleEcho(command, addToHistory, prefix)`** writes a line into the console. It replaced `ConsoleAddMessage`,
  which was removed in 11.1.0 ([wiki](https://warcraft.wiki.gg/wiki/API_ConsoleEcho),
  [removed](https://warcraft.wiki.gg/wiki/API_ConsoleAddMessage)).
- **Listing and console state.** `ConsoleGetAllCommands()` works on both clients. `C_Console` is nil on Forever and
  `GetAllCommands` is missing on retail [rule] forever.console.*. Also there: `ConsoleIsActive()`,
  `ConsoleGetFontHeight`/`ConsoleSetFontHeight`, `ConsoleGetColorFromType`, `ConsolePrintAllMatchingCommands`,
  `CalculateStringEditDistance`.
- **Console events** an addon frame can register:
  - `CONSOLE_MESSAGE(message, colorType)`: **every engine console line, live**;
  - `CONSOLE_LOG(message)`;
  - `CVAR_UPDATE(eventName, value)`;
  - `TOGGLE_CONSOLE`;
  - `CONSOLE_CLEAR`.

  So a test can capture console output into its own log without the window open.
  - `CONSOLE_MESSAGE` and `CONSOLE_LOG` are both `SynchronousEvent`. Whether they fire without `-console` is [?],
    one probe line.
- **CVars**
  - `C_CVar.GetCVarInfo` gives value, default, server-account and server-character storage, locked-from-user, secure
    and read-only.
  - `SetCVar` needs a non-read-only, non-secure, valid public CVar (`RequiresNonSecureCVar` and the like on the
    entry). Secure CVars, most nameplate ones, are blocked in combat.
  - `C_CVar.ResetTestCVars()` exists and matches `ResetTestCvars` [rule].
- **`C_ConsoleScriptCollection.*`** reads the client's console script collections (name, help, script, params,
  isLuaScript). It's unexplored and probably internal data [?].
- **`C_Debug.FrameXMLDebug(level)`** turns FrameXML.log detail on and off
  ([wiki](https://warcraft.wiki.gg/wiki/API_C_Debug.FrameXMLDebug)) [?] whether it's on Forever.
- **Blocked for addons:**
  - exportInterfaceFiles;
  - GM and Reveal commands;
  - secure CVars in combat;
  - anything that needs the console window or the glue screen.

  No public list of commands blocked from ConsoleExec exists [?].

## 4. The export (Forever, today)

- **Size.** `BlizzardInterfaceCode\Interface\AddOns\`: 349 addons, 4493 files (2880 .lua, 1262 .xml, 350 .toc,
  1 .xsd), 47 MB.
- **Every flavor is in one export, gated per file in the TOCs.**
  - TOC tags: `[AllowLoadGameType camelot]` (351 lines), `mainline` (485), `classic`, `vanilla`, `tbc`, `wrath`,
    `cata`, `mists`, `plunderstorm`, `wowhack`, `standard`.
  - **Forever is game type `camelot`.** Its files live in `Camelot\` subfolders (62 of them), for example
    `Blizzard_NamePlates\Camelot\Blizzard_NamePlateConstants.lua` and `...LevelFrame.lua/.xml`.
  - Anyone reading the code must follow the TOC: a `Mainline\` file may not load on Forever.
  - Shared code sits in `Shared\` folders, and `[Family]\` stands for the flavor folder.
  - The word "camelot" appears nowhere in Cinematic's code (only in a frFR locale string).
- **`Blizzard_APIDocumentationGenerated\`** holds 643 `*Documentation.lua` files.
  - They hold 410 systems, 6624 functions and 1816 events, **exactly the counts in our /api dump**
    (`forever.txt`: 410 / 6624 / 1816). So the export is the same data, readable without a game run.
  - Extras the dump drops: `Documentation = {...}` help strings (169 files) and `Environment = "SecureOnly"` (three
    systems: CombatLogSecure, FrameScript, PingManagerSecure).
- **Nameplate files.**
  - `Blizzard_NamePlates\`: Base, UnitFrame, HealthBar, CastingBar, Auras, ClassificationFrame, LevelFrame,
    RaidTarget, Component, Constants, FrameOptions, the driver, and the Mainline class bars.
  - `Blizzard_SettingsDefinitions_Frame\Nameplates.lua/.xml` holds the preview: `NamePlatePreviewTemplate` (xml:3)
    with `NamePlatePreviewMixin`.
  - What it answers for platematch:
    - the preview registers itself with `NamePlateDriverFrame:RegisterScriptNamePlate(self, "preview")`;
    - `PREVIEW_UNIT_TOKEN = "preview"` (Constants:26, the Camelot copy too);
    - it fills a fake `AurasFrame.explicitAuraList` and calls `RefreshExplicitAuras()`;
    - `SetExplicitValues` takes `isPlayer, isFriend, isMinion, isMinusMob, threatSituation, aggroFlash`, plus
      `classification` for the Classification frame (`NamePlateUnitFrame.lua:910`);
    - OnHide sends `NAME_PLATE_UNIT_REMOVED` for "preview" and unregisters.
  - (A hand-over note for the plate session is in the shared notes folder.)
- **Debug tools in the code.** `Blizzard_Console`, `Blizzard_DebugTools` (TableInspector, TextureInfoGenerator,
  TexelSnappingVisualizer), `Blizzard_EventTrace` (saves `EventTraceSavedVars`), `Blizzard_DebugUtil`,
  `Blizzard_CommandLineUtil` (fuzzy command scoring), `Blizzard_AddOnPerformance` and `Blizzard_PerformanceBar`.
- **Not done yet.** Retail needs its own export (`_retail_`). `art` hasn't been exported.

## 5. Upgrades for Cinematic's tools, ranked (biggest win first)

**Built 2026-11-23: items 9 and 10.**
- **Item 9: /perf.**
  - The game's per-addon figures were already saved with each recording (`CinematicDB.profiler.addons`, from the
    Profiler page). `Tools/perf/analyze.py` now reads them and writes an "Among your addons" section: Cinematic's
    place by the game's session average and by its worst frame (ms), all addons' total, and the top 5.
  - It warns when both Cinematic and CinematicDev were running.
  - The newest Forever recording (2026-11-19) shows exactly that: CinematicDev #1 (1.696 ms a frame) and Cinematic #2
    (0.809 ms) of 22 addons.
  - `--selftest` checks the parser. The /perf SKILL.md says to lead with the place.
- **Item 10: engine rules.**
  - `all.console.history-saved`, `forever.console.game-code-errors-logged` and `forever.console.log-files` are in
    ui-frames.lua; `forever.actioncam.test-cvar-echo` is in camera-movement.lua.
  - `forever.ui.game-type-camelot` was written by the nameplate session.
  - The enginerules check passes (339 rules).

**Built 2026-11-23: items 7 and 8.**
- **Item 7: /support.**
  - Its SKILL.md step 2 reads the game's code at any Blizzard frame in a player's stack, using
    `gamesource.py --at "<stack>" --client <their client>` (`--client` is new).
  - It warns about the wrong client's export and about other builds' line numbers.
- **Item 8: real template parts offline.**
  - `Tools/engine/templates.py` turns the game's XML templates into parts recipes, inherits merged, and writes
    git-ignored `api/templates-<client>.lua`: 54 templates on Forever. `--show` prints one.
  - `Tools/offline/templateparts.lua` (opt-in) gives stand-in frames made from those templates their real parts.
  - Check: `Tools/offline/templatepartscheck.lua`. It covers a hand-made recipe, TargetSpellBarTemplate's six parts,
    and the addon's player, unit and plate cast samples now built from their game templates instead of the drawn
    fallback. Retail is SKIP until it has an export.
  - The Style Lab takes `--game-parts`. Its default output is unchanged; with the flag, 153 shots differ (plates,
    cast bars, pages with check and edit boxes).
  - Not looked at closely in the lab page yet.

**Built 2026-11-23: items 5 and 6.**
- **Item 5: the Preview Match plan.**
  - `gamesource.py --template <Names>` gives, for each template: where it's made, whether it loads, its inherits and
    mixin, and which part of its inherit chain makes it secure.
  - `Tools/preview-match-plan.md` has a new "Step 0 from the game's code" table: 14 templates, found without a run.
    It agrees with the probe's table and adds three things:
    - Forever has no `Camelot\` copy of those templates;
    - BossTargetFrameTemplate is secure through TargetFrameTemplate;
    - Player, Focus, Pet and GroupLoot have no template.
- **Item 6: game code under every error.**
  - Under each error with a Blizzard frame, `gamesource.explain` prints that file:line from the export, with whether
    it loads and the lines around it. It skips `in function <...>` start lines.
  - It runs in /error (our log's errors and the console's) and in check log (the console's).
  - `gamesource.py --at "<stack>"` does the same for a pasted stack.
  - The /error SKILL.md says to read the `game code:` block before guessing.
  - Both selftests cover it.

**Built 2026-11-23: items 3 and 4.**
- **Item 3: the test kit and the console.**
  - `Dev/TestKit.lua` logs every `CONSOLE_MESSAGE` as `console:` / `console error:` / `console warning:` lines while
    a run goes, and every `CVAR_UPDATE` as `cvar: name = value`. Repeats are counted, and a run logs 150 lines at most.
    The end line gives the counts and the top repeats.
  - The context line adds whether the console window is open.
  - A test's `consoleWords = { "camera" }` lists every matching CVar or command, with its value, default, flags and
    help. `console = false` leaves it all out.
  - Offline check: `Tools/offline/testkit.lua`, 14 new checks, both clients.
  - Not yet run in game.
- **Item 4: apidocs.py reads the export.**
  - It runs the export's API documentation files through Dev/ApiDocsDump.lua's own code. On Forever its 9241 lines
    match the in-game dump exactly.
  - It adds 958 tables outside any system that the dump never reached (`T - ...`, the Enums with their values) and
    1030 help lines (`api/forever-help.txt`).
  - If both copies are there, it compares them.
  - `--selftest` covers it.

**Built 2026-11-23: items 1 and 2.**
- Item 1: `.claude/skills/test/gamesource.py` is known.py's `source` section, with a "read the game's code first" step
  in the /test SKILL.md.
- Item 2: `.claude/skills/test/gamelogs.py` is used by `read_log.py` and `/error`'s `recent_errors.py`, and both
  SKILL.md files say so.
- Each has a `--selftest`.
- Found while building: retail's saved console history (2026-11-20, never started with `-console`) holds Cinematic's
  own Lua errors. So the history, and likely `CONSOLE_MESSAGE`, works without `-console`, which mostly answers item
  3's open question.

1. **known.py searches BlizzardInterfaceCode, and the /test skill gets a "read the game's source first" step.**
   - known.py adds a `source` section: grep the export for the query words. It reports `addon/file:line` and the TOC
     game-type tag of that file, so a `Mainline`-only hit is flagged as not loading on Forever.
   - It does this for each client export it finds (`_forever_`, `_retail_`). If the folder is missing, or older than
     the client build (compare against the /api dump build line), it says so.
   - The SKILL.md "Know first" step adds this: before planning a probe about how a Blizzard frame, template or mixin
     behaves, read its code. That's the memory rule game-console-source-export.
   - *Saves:* whole probe runs. Platematch run 1, the template survey (`/cine debug templates`) and many "what does
     this mixin call" questions are one grep.
   - *Size:* small, about 60 lines of Python plus 5 lines of skill text.
2. **Read the console's saved history after every test ("check log").**
   - A small reader for `WTF\SavedVariables\Blizzard_Console.lua`, shared by `read_log.py` and
     `/error`'s `recent_errors.py`. It prints the color-3 errors and color-4 warnings from the test's time window.
   - It also reads `Logs\FrameXML.log`, which catches load-time syntax errors our own log can't, because the file
     never ran.
   - Blizzard-side errors such as today's `UnitWidgetSet` plate error, with no Cinematic frame on the stack, show up
     here but never in `CinematicDB.log`.
   - *Saves:* errors found a run earlier, and "the file didn't load" runs.
   - *Size:* small, about 80 lines, using lupa like `savedlogs.py`.
3. **The test kit captures console lines live.** `Dev/TestKit.lua` registers `CONSOLE_MESSAGE` and `CVAR_UPDATE`
   during a run and writes them into the run's log as `console:` lines (capped, deduped).
   - The engine's own word lands next to each step: `Test CVar ... set to`, `failed validation`, `LimitedLuaResources`
     capacity changes, Lua errors.
   - Camera and Shoulder Cam tests get every `test_*` write echoed back for free.
   - The context line can add `ConsoleIsActive()` and a per-test `consoleWords` list. That list runs
     `ConsoleGetAllCommands` and logs each match's value, default, flags and help, using the
     `C_CVar.GetCVarInfo` columns.
   - *Saves:* "did the setting really change, and to what" questions after a run.
   - *Size:* medium, about 60 Lua lines. It needs one probe line first: does `CONSOLE_MESSAGE` fire without
     `-console` (players don't have it)?
4. **apidocs.py reads the exported Generated docs straight.**
   - The export holds the same 410 / 6624 / 1816 as the in-game dump. apidocs.py can build `api/<client>.txt` from
     `BlizzardInterfaceCode\...\Blizzard_APIDocumentationGenerated\*.lua` with no `/cine debug apidocs` run, and keep
     the `Documentation` strings and the `SecureOnly` environment the dump drops.
   - Keep the in-game dump as the cross-check for "what loaded". A file in the export may be gated out by its TOC;
     the Generated TOC has 649 lines, worth checking for game-type tags.
   - *Saves:* one in-game run per client patch, and gives help text for known.py's apidocs hits.
   - *Size:* small to medium, about 80 lines; the Lua tables load with lupa as they are.
5. **Preview Match plan: step 0 is now just reading the code.**
   - `Tools/preview-match-plan.md` step 0.1 is done for Forever. Each preview row in its table can name its template
     file:line and whether a `Camelot\` override exists.
   - Retail needs its own export.
   - The plate preview mechanism, the script nameplate under "preview" with explicit values (§4), answers
     platematch's open questions without a run. That's the other session's call; see the note.
   - *Saves:* the remaining probe runs in that plan.
   - *Size:* a doc edit.
6. **The /error skill: Blizzard-side errors and `Camelot` awareness.** known.lua matching (`Tools/errors`) can take
   console-history errors as a second source. When a stack ends in a Blizzard file, the skill opens that file:line in
   the export to read the cause before guessing.
   - *Size:* small, mostly SKILL.md text plus item 2's reader.
7. **The /support skill.** When a player's stack points at a `Blizzard_*` file, read it in the export. That export is
   the matching client's, so the `_retail_` one is needed for retail players.
   - *Size:* SKILL.md text only.
8. **Offline stand-ins and the Style Lab.**
   - `Tools/offline/wow.lua` and `load.lua` (about 300 lines) hand-make frames. The exported XML gives each
     template's real parts, sizes, anchors, atlases and file IDs.
   - A one-time Python reader can turn a named template (`NamePlatePreviewTemplate`, the cast bar templates) into a
     parts table for the stand-in and for the Style Lab recipes.
   - Keep it offline-only and never ship it. The parts list is ours, the art stays the game's.
   - Running Blizzard's Lua offline isn't worth it: too many C APIs.
   - *Saves:* "the stand-in has a part the real frame lacks" misses.
   - *Size:* medium to large, about 200 lines. Do this last.
9. **The /perf skill.** `Blizzard_AddOnPerformance` shows the game's own ranking (`C_AddOnProfiler.GetTopKAddOnsForMetric`).
   A perf run could log Cinematic's place among addons. The console adds nothing for perf beyond `scriptProfile`,
   which is old.
   - *Size:* small, low value.
10. **An engine rule or two from today's findings.**
    - Console history is saved to `WTF\SavedVariables\Blizzard_Console.lua`.
    - The engine logs every `test_*` CVar write.
    - Forever = game type `camelot`.
    - Blizzard UI errors reach the console with scriptErrors off.
    - *Size:* tiny. Write them by hand per the README, then run the enginerules check.

## 6. Risks and what to leave alone

- **The account.** No Blizzard statement or ban report ties `-console` or `exportInterfaceFiles` to account action
  [?]. Both are shipped features, and the wiki's "Viewing Blizzard's interface code" page sends authors to them. GM
  and Reveal commands just say permission denied. Don't try them, and don't touch `C_ConsoleScriptCollection` scripts
  or the cheat browser.
- **Breaking settings.**
  - `cvar_default` with no name and `cvar_reset` reset every CVar. Server-synced ones (`synchronizeConfig`) may then
    sync those resets to the account. Never run either.
  - `ActionCam default` writes garbage [rule].
  - `taintLog 2` makes hooksecurefunc throw on Forever [rule]: turn it off after use.
  - Editing Config.wtf while the game runs gets overwritten.
- **The client.**
  - `exportInterfaceFiles` freezes the client until it's done, so run it at the character screen.
  - `SetConsoleKey` with a letter eats that letter in chat until a restart.
  - `gxRestart` has no known crash reports [?].
- **The license.** Read the export in place and never copy, bundle or paste Blizzard's code into the repo, the
  guidebook, or player replies (no-unlicensed-data). Tools may read it on this PC. Generated data stays git-ignored,
  as `Tools/engine/api` is today. Shipping `ConsoleExec` calls in the player copy is fine, as now. Never ship code
  that needs `-console`, since players don't have it.
