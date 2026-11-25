# Platynator

Version read: 550 (_forever_), 2026-11-25 (code read, not yet proven by a run of the recipe)

## What it is
Nameplates of its own, drawn over the game's.
- Its plates: unnamed frames made in pools, 40 per design, each parented to a game plate `NamePlate<n>` (Display/Initialize.lua:268-279). Each has `.kind`, `.widgets` and `:SetUnit` (how Support/Platynator.lua finds them). The game plate's own unit frame is moved into a hidden frame (Display/Initialize.lua:200-206).
- Its parts on a plate (health, cast bar, names, auras, markers): widgets of that plate, not frames of their own.
- Its customise window (`/platy`).

## How a player starts it
- Nothing to set up: no welcome, no on switch. Loaded, it takes every game plate (Core/Initialize.lua:77-100).
- `/platynator` or `/platy` opens its customise window; `/platy config <option> <value>` reads or sets an option; `/platy reset` wipes its settings and reloads (Core/SlashCmd.lua:5-9, :57-60, :72-80).
- Its saved settings: `PLATYNATOR_CONFIG.Profiles[PLATYNATOR_CURRENT_PROFILE]` ("DEFAULT" to start with) (Core/Config.lua:268-276).

## What each part needs before it shows
- A plate: a game nameplate for a unit near you (the game's nameplate distance), with the game's nameplate settings on for that kind of unit.
- Which kinds: its `show_nameplates` option (friendlyNPC, friendlyPlayer, enemy, enemyMinion, enemyMinor on; friendlyMinion off; Core/Config.lua:71-73), which it writes into the game's settings (`nameplateShowEnemies`, `nameplateShowFriendlyNpcs`...) at login, on loading screens and after fights (Display/Initialize.lua:425-460). Cinematic's Nameplates page rows decide those same settings (ns.FollowOthersPlateWrites).

## Set up for a test
- by code: nothing changed. The recipe only checks its show options, the game's nameplate settings and that one of its plates is up (Dev/PlatynatorSupportTest.lua).
- by hand: stand within about 20 yards of a few enemy mobs, out where mobs roam (friendly NPCs in a town work too, while their plates are on).
- by hand: the game's enemy plates off -> press V (the game's key for enemy nameplates, unless rebound).
- out of reach: its option calls (`addonTable.Config.Set`) are in its private addon table; writing its saved profile directly doesn't refresh its plates (no global call does), so a changed option would need a reload. The global `Platynator` holds only its `API` (API/Main.lua:4).

## Surprises
- It writes the game's nameplate settings itself (above), and `nameplateShowAll` from its "only needed" option (Display/Initialize.lua:430): a test that changes those settings sees them written back after the next fight or loading screen.
- It stops the game's nameplate driver listening to display size and (not on retail) setting changes (Display/Initialize.lua:93-96).
- Its plates set their own alpha all the time (target, mouseover, range, obscured): hooked (Support/Platynator.lua).
- `/platy reset` reloads: never send it from a test.
