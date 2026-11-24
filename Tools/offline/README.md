# Offline tools

The addon loaded outside the game, for checks and for looking at the profile modules. They need Lua 5.1
(`sudo apt install lua5.1`) and run from the repo root. Not packaged (`.pkgmeta` leaves `Tools` out).

Without Lua 5.1 (Windows), run any of them through `run.py` instead, which uses Python's lupa (`pip install lupa`):
`python -I Tools/offline/run.py Tools/offline/check.lua`. It runs each client's part through itself too, so nothing
looks for `lua5.1`. (Don't put a `lua5.1` stand-in on PATH: Windows asks what to open it with.)

- `wow.lua`: a stand-in for the game. Frames keep their parent, scripts, events and text; any other API call or global
  hands back a do-nothing stub.
- `load.lua`: loads a .toc's files in order on the stand-in, then fires `ADDON_LOADED` and `PLAYER_LOGIN` as a fresh
  install, so every options page is built.
- `pagecost.lua [forever|retail]`: what the settings pages make at login on the stand-in: frames and regions per
  page, their share of all the addon makes, and what opening each page made on first open adds.
- `lazyaudit.lua [forever|retail] [piece ...]`: what making a settings page on first open would break: per piece
  of the login build, the ns keys other files read, globals, events, hooks and timers; then every event,
  update, Why tab and Refresh with the waiting pages unbuilt (Tools/lazy-pages-plan.md). Exit 1 on a problem.
- `lazysearch.lua`: settings pages made on first open, both clients: the main search shows Searching... and makes
  the waiting pages over frames, then the same matches as with every page made; a hub's General switch makes
  only its hub's pages, with the same page switches as with every page made.
- `templateparts.lua` (opt-in, not on by default): frames made from a game template get the template's real parts.
  - That means `frame.Icon`, `.Spark`, `.Text`, the child frames, and each part's atlas or file, size, layer,
    anchors and hidden flag. Without it, the stand-in hands back a stub or nil.
  - The parts come from the game's own XML: `Tools/engine/templates.py` makes
    `Tools/engine/api/templates-<client>.lua` from the console's `exportInterfaceFiles code`. That file is
    git-ignored, since it's Blizzard's data.
  - To use it: `dofile("Tools/offline/templateparts.lua").Use(client)` in load.lua's onInstall. It returns nil and
    why when there's no file.
  - Check: `templatepartscheck.lua`. It covers a hand-made recipe, then the game's recipes when they're there (else
    SKIP): TargetSpellBarTemplate's parts, and the addon's player, unit and plate cast samples built from their game
    templates instead of the drawn fallback.
- `check.lua`: `lua5.1 Tools/offline/check.lua` runs the profile modules' checks (ProfileModules.lua) on both clients
  and both builds. It exits 1 on any problem. CI runs it on every push (`.github/workflows/checks.yml`).
  It also compares each built-in profile's settings, retired ones too, with `profile-settings-<client>.txt`, so a
  change to a module or a choice shows in every profile it reaches. When that change is meant, run it with
  `--update` to save the new settings, and commit the files with the change.
- `sweep.lua`: `lua5.1 Tools/offline/sweep.lua <forever|retail>` runs the settings sweep (Dev/Sweep.lua) on the
  stand-in: every page opened, every setting changed and put back. The stand-in's stubs make FAIL lines of their own,
  so they're compared with `sweep-baseline-<client>.txt` and only new ones fail it; `--update` saves this run's as
  the baseline. `SWEEP_DEBUG=1` prints one raw line per erroring code line.
- `noaddons.lua <forever|retail> [--all]`: no other addon's support runs while that addon isn't loaded. Loads with
  no other addon in (their globals missing), every page on, then runs every update loop, timer and event (stand-in
  nameplates, CineMode off then on) and counts each call into a `Support/*.lua` function or a function named after
  a supported addon: each is a LEAK line with its callers, to gate with `ns.AddonUp(name)` (AddonSupport.lua). It
  fails too if the drive missed a hot path (frames, plates, plate fades, minimap reveal), and checks addons loading
  late (after Cinematic, after login): `ns.AddonUp` says so at once and Questie's support runs on the same paths
  again. About 30 s a client. `NOADDONS_SECONDS` sets the drive's length, `NOADDONS_PROGRESS=1` prints its steps
  and slow or stuck handlers.
- `partyflicker.lua`: a stand-in for DaylightUI's party tile dimming itself by a secret range answer
  (SetAlphaFromBoolean), checked against our fade: its dim kept while not faded, our fade back at once while faded.
  An optional .toc argument runs it on other code (a copy with an older Frames.lua, say).
- `boxwords.lua <forever|retail>`: a number box that shows words (Letterbox Style's How long, "With the UI" at 0)
  holds and fits its whole text, with the game's letter cap kept on the stand-in.
- `previewwatchon.lua`: the dev copy watches the Style previews by itself from login (Dev/PreviewWatch.lua), logs
  their moves, and stays off once turned off.
- `tooltiplocation.lua`: the Tooltips page's Location row. A party member's zone on their short tooltip goes
  by it, apart from Spec and class, and a full tooltip's faction line under the class isn't taken for the zone; the
  update starts Location as Spec was set.
- `tooltipnowait.lua`: the Tooltips page's No wait for list (Quest objective mobs) with the tooltip's unit
  secret, as in a fight on WoW Forever: by the unit frame's unit, else the mouseover and the target or plate
  that is the same unit; nothing taken from an unreadable UnitIsUnit.
- `testkit.lua`: the test kit (Dev/TestKit.lua) through `/cine debug kitcheck` with pretend time, both clients: every
  step passes, context and probe lines (mana secret on Forever), the undo put back at the end, on a stop and at the
  next login after a cut-off run, CineMode kept off and back after. Copy it for a kit test's own offline run.
- `testqueue.lua`: the test queue (Dev/TestQueue.lua) with kitcheck as the queued test, both clients: the offer at
  login, Run all with a result line and a log copy per id, a name that isn't a kit test passed over, Stop queue,
  a test's Reload button carrying the queue over, a /reload of your own cutting it off, tidy and clear. The
  sessions' side, `Tools/testqueue.py`, has its own `selftest`.
- `healtworules.lua`: Heal Vision's Unit Frames and Nameplates tabs each have their own Show in rule (frames start in
  dungeons and raids, plates everywhere but cities), the saved rules' once-only update and the page's Reset.
- `healauras.lua`: Heal Vision's Debuffs: Show while hidden tick (healVisionKeepAuras, off to start with): raid-style members faded by their parts,
  not whole, their aura icons and forbidden parts left at full, the game's own frame alpha left alone; the page's tick found and clicked on; and
  `/cine debug healauras` (Dev/HealAurasTest.lua) through to DONE, settings and the row's rule put back. Both clients.
- `loopsoff.lua`: a feature loop runs no update loop with its page off, even with the page's rows ticked, and
  starts again with the page (Heal Vision's kept going every frame). And the settings pages made ahead wait while
  `/cine debug loops` measures, so their time isn't counted as the loops'.
- `chatdefault.lua`: the Chat page's Show just those messages copies lines only with the game's own chat; with
  EllesmereUI's, ElvUI's or Glass's window (a chat window link claim) or Chattynator a message shows the window.
- `zonecardnewzone.lua`: /cine debug zonecard 10 (New zone off by default) through the kit on both stand-ins, pretend time and card fades: passes, fails for a player still on, puts back.
- `newzonedefault.lua`: the New zone card off to start with and turned off once by the update (here, profiles, reset points), so a new zone gets Discovered's small card ("DUN MOROGH", 2026-11-23); ticked again it stays on.
- `discoverinstance.lua`: out of a dungeon, the game's zone name still the dungeon's a few seconds: no card for it (the big New zone card for "Stormwind Stockade", 2026-11-23); a new zone after still gets New zone's, a dungeon new to you Discovered's. Optional .toc argument runs it on older code.
- `cardwait.lua`: the Rested card waiting while DaylightUI's zone title shows (ns.AddCardWait), on a clock of its
  own: waits, shows once the title's gone, gives up after 8 s, no wait without the title or for other cards.
- `cooldownnever.lua`: the Cooldown Manager page's Icon shows Never. The mode read back for a spell, its override, a
  group and a numbered line; the dropdown and profiles carry it; and the ready pass fades a Never icon (a
  flashing one too) while an Always one beside it stays.
- `cooldowngrid.lua`: the Cooldown Manager page's grid: place groups across, cells per row (UI/CooldownRules.lua,
  UI/CooldownGrid.lua, in place of the numbered lines), the page's clicks, and the update from lines.
  Fitting by Combat and Location or CQL, top to bottom with the row's own dropdown last, a spell's lines before its
  bar's, buffs too; a typed rule back into the dropdowns; the page's block adding, moving, deleting and lighting the
  line in use; the ready pass fading by a line; and the update turning saved situations into lines.
- `combattextkeep.lua`: Combat Text Style's game-number settings kept as its rows say: a reset of the game's options
  (an outside write) put back, Game's handing them over, the page off and Keep yours letting go; a plain "your
  change wins" set still lets go.
- `servicefardim.lua [forever|retail]`: the Friendly NPCs tab's "Far, behind walls" slider (nameServiceFarDim):
  past 28 yards only Service NPCs names fade to it while their plates are dimmed; near ones hide; none in fights.
- `notchgap.lua <forever|retail>`: full-screen effects (ns.CoverWorld: letterbox, tint edges, death screen, Focus,
  low health, teleport) reach up over a Mac's camera notch strip above UIParent, at UI scale 1 and 0.8, and come back
  down when it goes.
- `reload.lua <forever|retail>`: our reloads (QoL/Reload.lua). Forever, where ReloadUI from our code is blocked: a
  popup that reloads gets a secure /reload button over the right button, whose click runs the popup's work without
  our ReloadUI, and with no such click it says to type /reload. Retail: ReloadUI as before, nothing covered.
- `castlook.lua <forever|retail>`: a cast bar's These bars pick of the other kind's game look (PlateCastStyle.lua's
  GameAs/DressAs) on the style lab's real-layout stand-in: put on (border, name, icon as the game lays the other kind
  out) and taken off again (every anchor, size and justify back).
- `gryphons.lua`: parts that ignore their frame's alpha follow our fade (FadeDetached.lua). Action bar 1's
  gryphons on Forever, made to ignore EndCaps' alpha by another addon (FlareUI 6.13): the HUD's Action bar art row
  and the Overrides tab's Hide still reach them (kept down if that addon raises them, following a half fade, handed
  back after). And any faded frame: another addon's detached part follows it, Cinematic's own stays, /cine why
  says who detached it.
- `loosesurvey.lua`: `/cine debug loose` (Dev/LoosePartsSurvey.lua, step A of Tools/loose-parts-plan.md) on the
  dev copy: finds exactly the parts under faded frames that ignore their alpha (regions, children, deeper ones),
  not frames with a row of their own or our own detached parts, counts secret answers apart, changes no alpha.
- `menurows.lua`: menu title/divider rows our code adds (ns.MenuTitle / ns.MenuDivider) aren't blocked in a fight on Forever (gamepad mode on or off), and stay the game's own rows on other clients
- `quietblock.lua`: Settings opened in a fight with Forever's gamepad UI: its blocked lines are known by their stack
  (our pick + SetSecureValue) and kept out of the dev error box, a pick from any caller marks the fight, and the
  game's own Escape > Options still shows (Tools/errors/known.lua `settings-pick-in-fight-gamepad`).
- `matrix.lua`: the audit kit's state matrix (`/audit` skill, `Tools/audit.py`, fix cards in `Tools/audits`). A test
  lists the states a behavior reads (dimensions), returns one outcome per combination (a `CELL` line each) and pins
  every cell (PASS/FAIL; an unpinned cell FAILs). `python -I Tools/audit.py diff <test> [client] --base <ref>` runs the
  same test on the old code and the new and FAILs on any changed cell no fix card declares.
- `zonecardmatrix.lua [forever|retail]`: the game's zone, subzone and territory lines around a Zone card, 32 states
  (place, last card up or gone, within the gap or after, Subzone row, Territory tick); the first matrix (fix card
  `Tools/audits/2026-11-23-zone-card-gap.md`).
- `Tools/prerelease.py` (one folder up) runs these checks and the rest side by side before a release, and reads the
  in-game `/cine prerelease` results from the saved settings.
- `export.lua`: `lua5.1 Tools/offline/export.lua > profiles.json` writes the options pages and their sections, the
  modules and the built-in profiles as JSON, for mock-ups and the like.
- `hublasttab.lua`: the tab last open under each settings icon (db.hubLastTab) kept through a /reload and a loading
  screen, forgotten by a real login, so each icon opens on its own page after a logout. One item's pages (`forget` in
  HUBS: Card Settings, Card Style, Card Sounds, Trigger Settings) are never saved: their icon opens its list page.
