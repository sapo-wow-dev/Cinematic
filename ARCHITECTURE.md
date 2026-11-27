# How Cinematic is put together

A one-page map for anyone (or any session) about to change the addon. It says
where things live and which rules every part follows. Each file's own header
comment has the details. Not packaged for players (`.pkgmeta`).

## Load order

Both TOCs load the same files in the same order. The dev copy
(`CinematicDev.toc`) adds its test and dev-only files on top, and
`Tools/check-toc.py` checks that.

1. **Before Core:** `Modules` (the parts that can be left out, below),
   `Checks` (`ns.Check`: ask the game before calling), `FrameGuess`,
   `FadeDetached`, `Locales/` (`ns.L["English text"]`), `Diagnostics` (log,
   error net, protected loops), `Profiler` (`ns.Profiled`), `Graphics`.
2. **`Core.lua`:** client flags (`ns.isRetail`, `ns.isClassicEra`),
   `DEFAULTS` (most of them), CineMode itself and the main tick, then the
   ADDON_LOADED/PLAYER_LOGIN handler (settings updates via
   `ns.RunMigrations`, defaults filled in, profiles, slash command).
   `Migrations.lua` right after it holds the once-only settings updates, in
   steps.
3. **The fading machinery:** `Skin`, the rule editor (`UI/GridRows`,
   `RuleCatalog`, `RuleEditor`), `HideUI`, `AddonSupport` and every
   `Support/` file, then `Frames.lua` and `RuleAxes`.
4. **Features**, roughly by area (below). Each one builds its frames at load
   and hooks into the tick, events or signals.
5. **Last:** `Slash`, `Why`, `SelfTest`, `Profiles/`, `Conflicts`,
   `LazyPageDefaults`, `Options.lua` (the settings window), `Find`,
   `Favorites`, then `Changelog`/`WhatsNew`, `ProfilerPage`,
   `GameSettingsPage`, `MinimapButton`, `Reload`, `AddonListAll`.

A file can only use another file's `ns.X` at load time if that file is
earlier in the TOC. Inside functions that run later, any `ns.X` works.

## Parts that can be left out

Visions, Cameras, Style and Atmosphere can each be switched off on their hub's
General page (`CinematicDB.load<Part>`, outside the profiles, needs a
`/reload`). Their files still load, but only their settings and data run at
load: the rest of each file is a function handed to `ns.Module(name, fn)`,
and `ns.RunModules` runs those in TOC order first thing at ADDON_LOADED, each
part's unless it's left out. What the rest of the addon calls on a part
without checking first has a do-nothing stand-in in `Modules.lua`.
`Tools/offline/modules.lua` checks both ways.

## What runs while you play

No single main loop: several update loops run side by side, each on its own
frame, each only as often as it needs.

- **The update tick** (`Core.lua`, its OnUpdate). Called every frame, it
  works at most every 0.03 s (`TICK`), and with nothing changing only every
  0.1 s in CineMode and 1 s out of it (`ns.Pace`, `idleTick`); a fight
  starting skips the wait. It's split over two frames. On a tick it looks
  for new frames (a piece at a time), decides CineMode
  (`ShouldBeCinematic`), runs the **frame pass** if one is due, and leaves
  the rest (`tickRest`). At the top of the next frame that rest runs: the
  calm timer, the effects (letterbox, tint, CVars, music, plates, tooltip,
  taxi) and `ns.lastCinematic`, so that changes a frame after the decision.
  Every step goes through `Step`, so one error doesn't stop the others.
- **The frame pass** (`Frames.lua`, `ns.UpdateFrames`). Runs at once when
  CineMode, a fight or immersive changes, the mouse goes on or off a faded
  frame (`ns.HoverProbe`), a modifier key is down, you're typing, or
  `ns.framesWake` is set; otherwise on a timer (0.5 s out of CineMode, 0.25 s
  in it or 1 s with `ns.SlowChecks`, 0.125 s in a fight, 0.5 s once its fades
  are done). With frames still fading and nothing else changed,
  `ns.UpdateFadingFrames` moves only those on. A full pass asks each Show in
  row's rule (`ns.RuleShows`, ticks if it has none) for the list of shown
  frames (kept 0.2 s at least, worked out again at once on a fight, target,
  cast...), gives each frame in `ns.managed` a target alpha from that, the
  mouse, peeks, chat, death and immersive, and steps it there with
  `ns.SetEntryAlpha`, which then calls `ns.SyncDetached` (FadeDetached.lua).
- **The camera motion loop** (`Core.lua`'s `ns.orbitFrame`, "the orbit";
  not the `/cine orbit` script). Every frame while one of our cameras has
  something to do, since it changes camera speed smoothly; with nothing to do
  it takes its OnUpdate off (`ns.OrbitQuiet`, Camera.lua) until the director
  wakes it (`ns.WakeOrbit`). Not started with Cameras left out.
- **The camera director** (`Director.lua`, its own frame). Looks at a few
  cheap things 30 times a second (4 when quiet), or every frame through the
  motion loop while that's awake, and works out the scene (`ns.DecideScene`,
  Camera.lua) when one changes or an event wakes it, otherwise every 0.1 s.
  Moves go through `ns.CameraCall`, which lets one camera hold the view at a
  time and never while you're moving it (`ns.ClaimCamera`); `ZoomGuard.lua`
  holds our zooms if they swing in and out.
- **Feature loops** (`ns.FeatureLoop`, Diagnostics.lua): a feature's own
  OnUpdate, there only while its `wanted()` says so (asked once a second and
  on the feature's wakes). Many other loops are set with `ns.SetOnUpdate`,
  some at load and most only while something animates.

The tick, the motion loop and the director start together at PLAYER_LOGIN
and stop together on a safety stop (`ns.Suspend`), till `/cine resume`.

## Building blocks to reuse

| Need | Use | Where |
|---|---|---|
| An OnUpdate | `ns.SetOnUpdate`, `ns.HookOnUpdate`, `ns.FeatureLoop` | Diagnostics.lua |
| A setup step that mustn't stop the rest | `ns.Guard(fn, ...)` | Diagnostics.lua |
| Whether a value is secret, or a frame reachable | `ns.Check.Secret`, `ns.Check.Reachable`... | Checks.lua |
| Code a left-out part mustn't run | `ns.Module(part, fn)`; `ns.ModuleLoaded(part)` | Modules.lua |
| Timing a busy function | `ns.Profiled(name, fn)` | Profiler.lua |
| Another addon's setup | `ns.WhenAddonLoads(addon, fn)` in `Support/<Addon>.lua` | AddonSupport.lua |
| "Something happened" between files | `ns.Listen(name, fn)`, `ns.Signal(name, ...)` | Core.lua |
| A setting, page switch included | `ns.Setting(key)`, `ns.PageSetting(key)` | Core.lua |
| A Show in row (Always, fights, places) | `ns.ShowTable` and the CQL rules (`ns.RuleShows`) | Options.lua, Frames.lua, GridRows.lua |
| A rule typed by hand | `ns.OpenRuleEditor(target)`; axis words (`zone:1453`) in RuleAxes.lua | UI/RuleEditor.lua |
| Opening a settings page | `ns.OpenOptions(page)` and `/cine find <id>` | Options.lua, UI/Find.lua |
| Text the player reads | `ns.L["English text"]` (American spelling) | Locales/ |
| Why a frame is up | `/cine why`; a new reason needs a line in Explain | Why.lua |
| Why a feature is on | `/cine why` tabs: ns.WhyProvider (a tab's rows), ns.WhyMoment (Recent) | WhyPanel.lua, WhyFeatures.lua |

## Areas (one folder each)

- **Top level, the core:** Core, Migrations, Modules, Checks, Diagnostics,
  Profiler, Frames (the fading frames and the frame pass), FadeDetached,
  RuleAxes, Effects (names, plates, CVars and how the letterbox bars are
  drawn in CineMode), Options (the settings window), LazyPageDefaults, Skin,
  Graphics, AddonSupport, Conflicts, Slash, SlashComplete, SelfTest,
  Changelog, WhatsNew, ProfilerPage, GameSettingsPage, MinimapButton,
  FrameGuess.
- **`Support/`:** one file per other addon, one row per frame.
- **`UI/`:** what shows when: HideUI, GridRows (Show in rows), RuleCatalog
  and RuleEditor (the CQL editor), FrameLinks, QuestStandIn, Chat, ChatCopy,
  Bubbles, Speech, SpeakerWatch, ShareWindow, Tracking, NodeSweep,
  CursorHide, PersonalResources, the Cooldown Manager's files (Cooldown*),
  TooltipParts, Why/WhyPanel/WhyFeatures, Find, Favorites.
- **`Camera/`:** Camera, Director, ZoomGuard, QuestCam, ShoulderCam (and
  Calibrate, MultiQuestFix), SkyrideCam, ChatCam, CameraRows, Triggers,
  TriggerLibrary, CustomTriggers, Shots, CameraScripts, CameraTests,
  CameraWheel, ChatCamSubtitles, CameraManager (Camera > General), and their
  pages.
- **`Atmosphere/`:** Letterbox, Music (both out of Effects since
  2026-11-22), Tint, DeathVision, Focus, WeatherFX, ScreenEffects,
  LowHealth (Vitals), VitalsSound, ManaVision, TeleportVision.
- **`Visions/`:** Cards, CombatVision, CardMoments, ZoneCard, Recap,
  EmoteVision, RollWindow, QuestTalk, TalkingHeads, QuestMobs, QuestGlow,
  QuestMarkIcons, QuestItemButton, HealVisionFrames, DamageVision,
  DamageReport, CombatSounds, TimeOfDay, FlightLine, SleepingBag.
- **`Plates/`:** PlateSleep (plates showing nothing skip their work),
  PlateParts, PlateIcons, PlateGuild, PlateCopy, PlateLayout, NameRowLook,
  PlateRowLook, PlateThemes, NameThemes.
- **`Style/`:** StylePages (shared rows), StyleThemes, GeneralStyle, one file
  per page (`*Style.lua`), InterfaceRecolor, StyleOverrides, the personal
  mana bar, ThemeShots, PageShots, and `Studio/` (Style Studio: the
  editor window and its per-frame recipes, `ns.OpenStyleStudio`).
- **`QoL/`:** Campfire, Hunter, HunterAmmo, DragEquip, TalentLink,
  TalentCalc, CenterPanels, AhDressUp, XpLeft, KeyboardMap, IconBrowser,
  Reload, AddonListAll, the wheels.
- **`Profiles/`:** ProfileChoices (what players pick), ProfileModules (the
  settings behind each pick), Profiles, Share, Backups, Welcome, ShowMe,
  Layouts, FollowHud.
- **`Dev/`:** everything only the dev copy loads (tests, demos, dev pages).
  None of it ships (`.pkgmeta` leaves out the folder).

A new file goes in its area's folder, in both TOCs at the same spot (the TOC
check says if not). A TOC change needs the game restarted, not a `/reload`.

## Clients

One addon for every client the TOC lists: retail, Mists, Cataclysm, the
Classic progression clients and Classic Era, WoW Forever first (where it's
tested most). Each client keeps its own settings. Where clients differ is in
the code (`ns.isRetail`, `ns.isClassicEra`, feature tests), not in separate
files, except the offline check's per-client lists.

## Rules every change follows

- **Only `SetAlpha` on Blizzard frames, never `Show`/`Hide`/`SetPoint` on
  protected ones, and no field writes on them.** State goes in a side table
  with weak keys. Hook with `hooksecurefunc`, never replace a game function.
- **Feature-test, don't version-test.** Check that an API or frame exists
  (`C_Spell and C_Spell.GetSpellName or ...`). `ns.isRetail` only for
  differences by design. A fix for one client must not change the other.
- **Secret values** (Forever and retail, in fights): don't compare, do
  arithmetic on, or concatenate a value that may be secret. Use
  `issecretvalue` or `pcall` it.
- **Lua 5.1 limits:** 200 locals per function (the file's main chunk counts),
  60 upvalues per closure. Big files are near the cap: put new helpers on a
  table or inside a `do ... end` block. The offline check catches going over.
- **Settings:** a new setting goes in `DEFAULTS`, its page's Reset uses it,
  and a page switched off turns off everything on it. Changing an existing
  default for players already playing needs a once-only update at the end of
  `Migrations.lua`, with a `...V1` flag. Check it with
  `Tools/offline/migrate-test.lua`: it runs every update on a real saved
  settings file, with each flag off, so two versions can be compared.
- **Before committing:** `luacheck .` and the offline check
  (`python -I Tools/offline/run.py Tools/offline/check.lua`). The pre-commit
  hook runs both (`Tools/hooks/`, see below). Then the whats-new skill.

## Checks and numbers

- `Tools/hooks/pre-commit`: luacheck, the TOC check and the offline check, on
  every commit. Turn it on once per clone with
  `git config core.hooksPath Tools/hooks`.
- `Tools/check-toc.py`: the dev TOC matches the release TOC.
- `Tools/offline/`: the addon loaded outside the game on a stand-in
  (`wow.lua`), with a few hundred checks; `check.lua` is the main one.
- `Tools/engine/`: what the game engine does, found by tests, one rule each
  (the base for "would this work?"). `Tools/errors/`: known errors.
  `Tools/tests/`: a ledger per feature's in-game tests.
- `Tools/stats.py`: lines, files, the longest functions, files near the local
  cap and the saved-settings size, with a line added to `Tools/stats.csv` so
  growth shows over time (`--save`).
