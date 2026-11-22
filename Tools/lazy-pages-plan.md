# Settings pages made on first open: plan

Step 2 of growth-plan.md D. Measured 2026-11-22 (Forever, `/cine debug pagecost`, Tools/tests/page-cost.md):
the pages built at login take **589 ms** and **13-22 MB of Cinematic's 41 MB** (Lua only; the game's own frame
memory comes on top), 7,381 frames and 32,598 textures/texts. The 6 pages already made on first open
(`lazyPages.Add`: HUD, Hover Groups, Nameplates, Nameplate Style, Card Vision, Card Sounds) keep 13 MB and
288 ms out of login. Most players never open most pages.

Goal: login builds only the page shells (canvas, menu entry, hub tile); a page's body is made the first time
anything needs it. Target: login build under 100 ms and a few MB.

## How it works today

- `lazyPages.Add(canvas, name, build)` (Options.lua): the body is made on the canvas's first OnShow, or by
  `ns.MakeLazyPages(why)`. A build can step through frames (coroutine, `ns.PageBuildStep`, 3 ms a frame).
- Everything that reads every page builds them all first: the search (`BuildSearchIndex` via
  `ns.searchPrepare`), `/cine find`, `ns.PageSettings` (profile modules, dev/offline), `ns.SettingIds`,
  `ns.FindableIds`, a hub's General switch (`ns.CascadeHub`), the sweep and a few dev tests.
- Page switches and hub tiles already work with HUD and Nameplates unbuilt.

## The catch: the search

The search reads live frames (labels, tips, which rows are shown) and highlights the match, so it needs every
page built. With most pages lazy, a player's first search would build them all at once: about 0.6 s in one
frame. Two ways:

- **A. Build in steps on first search** (recommended first): the search box says "Searching..." and builds the
  waiting pages through the existing coroutine at 3 ms a frame (about a second), then shows results. No new
  data to keep right. Memory comes back for that session once someone searches.
- **B. A saved catalog**: each page's entries (label, tip, setting key, row id) kept in saved settings per
  version and language, searched without building; opening a result builds just that page. Instant and no
  memory, but rows hidden by your settings would show, and a stale catalog is possible in the dev copy.
  Only if A feels slow in game.

## Phases

0. **Audit tool (offline, first).** Extend Tools/offline/pagecost.lua: for a page made lazy, what its builder
   puts into `ns` and `_G` that other code reads at login or play (the real risk: a function defined inside a
   builder, a control another file reaches into). Then run every frame's events, OnUpdates, Refresh and each
   Why tab with the page unbuilt, no errors (as Tools/offline/modules.lua does for left-out parts), and again
   built. Each finding: move it out of the builder, or a check where it's read.
1. **Search waits for the build (way A)**, `/cine find` too (finished at once there: a command). Hub General
   switch builds only that hub's pages, not all.
2. **Move pages, heaviest first**, each wrapped in `lazyPages.Add` the way HUD is: Advanced Frames (3.5 MB,
   48 ms), Addon Links (2.1), Style Themes (2.0), Chat (2.0, 33 ms), Graphics (1.4), Tint Style (1.2),
   What's new (1.0, 43 ms), Style Overrides, Keyboard Map, Style General, Reveal, Module Editor (dev),
   Wheels, Tooltips. Then the rest in batches by file (Style pages, Visions, Camera). One commit per batch, the
   audit clean for each.
3. **Confirm**: `/cine debug pagecost` again (login build ms and KB, the lazy list), and the settings sweep
   (`/cine debug sweep`: every page opened, every setting changed and put back) so each moved page still
   works once built.

## Phase 0 results (2026-11-22, both clients the same)

`python -I Tools/offline/run.py Tools/offline/lazyaudit.lua [forever|retail] [piece ...]` (Options.lua's
`ns.settingsLapHook` marks each piece of the login build). The 6 pages made on first open today: 0 problems
while unbuilt (events, updates, Why tabs, Refresh). Of the 84 pieces built at login, what a move must handle:

| Piece | Read elsewhere | What to do when it moves |
|---|---|---|
| Profiles, Reveal (first pages) | ns.settingsCanvases, ns.tabRows, ns.settingsCategory | none: made by the shared page helpers, which stay at login |
| Reveal (CineMode) | ns.OpenCineModeOverview (Profiles/Welcome.lua) | Welcome falls back to opening the page: build the page in it, or move the function out |
| Advanced Frames | ns.OnAddModeChanged (Frames.lua, /cine add mode) | guarded; the page's own state is made fresh on build, so fine as is |
| Scenes (CreateCamerasPanel) | ns.SceneRowLabel, ns.SceneRowTriggers, ns.ShowSceneRow (Camera/CameraManager.lua, UI/GridRows.lua) | guarded, but Camera Manager would show bare keys: move the label helpers out of the builder; ShowSceneRow builds the page first |
| General Style | ns.generalStylePreview (InterfaceRecolor.lua, StyleOverrides.lua share it) | those two pages need General Style made first: their builders make it |
| Vitals Style, Card Vision | ns.VitalsPageDepth, ns.CardPageDepth (Slash.lua debug) | guarded with "open the page first": fine |
| Cooldown, Style Themes, Card Styles, Quest Item Style, Game Settings, Plates | dev tests only (ns.CdmPageRows, ns.themePicker, ns.STYLE_PREVIEWS, ns.LOOK_PANELS, ns.GameSettingsPage, ns.PickPlatesIcon) | those tests build their page first |

Events registered by page frames (they'd wait till the page is made: check each only refreshes the page):
Profiles (PLAYER_REGEN_*), Cursor Hide, Wheels, Keyboard Map, Keybinds (UPDATE_BINDINGS), Cooldown
(CVAR_UPDATE), Tint Style (ZONE_CHANGED*), Shoulder Cam (PLAYER_MOUNT_DISPLAY_CHANGED, UNIT_MODEL_CHANGED,
UPDATE_SHAPESHIFT_FORM), HUD already lazy (EDIT_MODE_LAYOUTS_UPDATED). Named frames: the numbered
CinematicOptionsSliderN / CinematicCastSampleN only (nothing reads them by name; the numbers will shift).
No piece hooks a game function.

## Phase 1 done (2026-11-22, offline)

- The main search and each page's own search box: with pages waiting, "Searching..." and
  `ns.MakeLazyPagesSoon` makes just the pages that box searches, one at a time a few ms a frame, then the
  matches (in a fight: made at once, as before). `/cine find`, the ids and the sweep still make them at once.
- `ns.MakeLazyPages(why, pages)` takes a page list; `lazyPages.Waiting(pages)` (a page's canvas or one in it).
- A hub's General switch makes only that hub's waiting pages.
- Checked by `Tools/offline/lazysearch.lua` (both clients: Searching... shown, pages made over ~700 frames,
  the same 12 matches as with every page made; UI Manager's and Visions' switches make only their pages,
  the same switches as with all made), `lazyaudit.lua` (0 problems), the sweep (0 new FAIL), check.lua.
- Not yet in game: goes in the phase 3 run.

## Phase 2, batch 1 (2026-11-22, offline)

Moved onto lazyPages: **Advanced Frames** (Options.lua, the whole page below its switch and hub icons),
**Chat** (below its switch), **Addon Links** (UI/FrameLinks.lua: the link sections; the tab hosts and their
switches stay, the hub tiles show them), **Graphics Boost** (below its switch), **New features**
(WhatsNew.lua; All changes already built when shown). In game they were about 10 MB and 150 ms of the login
build by its own count (page-cost.md run 1).

- New: **LazyPageDefaults.lua** (both tocs, before Options.lua): the tab switches' defaults (tabOn:...) that
  these pages make as they're built, put into DEFAULTS at load, so profiles, sharing and Reset carry them
  before a page is first opened. Nameplates had been missing its 9 since it went lazy (2026-11-16).
  `lazyaudit.lua <client> --write` makes each client's list; the audit fails when a page's build makes one
  not listed (18 now: Chat 4, Graphics 5, Nameplates 9).
- The audit also tracks DEFAULTS made by each piece of the login build.
- Stand-in, Forever: objects at login 11,791 frames + 31,902 regions -> 9,237 + 24,310; the ADDON_LOADED
  Lua +43.0 MB -> +30.5 MB.
- Checks: lazyaudit (both clients, 11 pages waiting, 0 problems), lazysearch, the sweep (0 new FAIL on both),
  check.lua (profile lists unchanged), pagecosttest. modules.lua fails only on "Breath Bar" with Style left
  out: another session's Style/Atmosphere module work in progress, not these pages.

Next, not done: the Style pages (Style Themes 2.0 MB, Tint Style 1.2, Overrides 0.9, General 0.8) share the
rotating preview and docking, and another session is making Style a module now: wait for it. Then Keyboard
Map (0.86), CineMode/Reveal (0.76: ns.OpenCineModeOverview for Welcome), Wheels (0.57), Tooltips (0.56).

## Tests

- Offline, per batch: the audit (phase 0), `Tools/offline/pagecosttest.lua`, `check.lua`, the sweep on the
  stand-in (`sweep.lua`, against its baseline), luacheck.
- In game, one run at the end (Forever): `/cine debug pagecost` (numbers before/after in the ledger) plus the
  sweep. If the search way changes (A to B), its own step in that run.

## Not in this plan

- A separate load-on-demand settings addon (growth-plan D step 3): only if memory still matters after this.
- Making the files' code itself not load: the page code is still read at login (the files are in the .toc);
  this saves the frames and tables, not the parsing.
