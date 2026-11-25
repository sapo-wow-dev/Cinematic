# MikScrollingBattleText_Forever

Version read: v2.1.1 (_forever_; its folder also has a _Camelot toc), 2026-11-25 (code read, not yet proven by a run of the recipe). Support/MikScrollingBattleText.lua was read from 2.0.8; it waits for "MikScrollingBattleText_Forever" (the folder name), so the recipe is under that name too.

## What it is
Mik's Scrolling Battle Text, the Forever copy: your incoming and outgoing damage, heals and notices scroll in areas round the middle of the screen.
- Its text: every area's lines draw on one frame, `MSBTAnimationFrame` (Display/AnimationEngine.lua:481), shown only while some text is moving and hidden again once all of it is done (:373, :476).
- Its scroll areas (Incoming, Outgoing, Notification, Static) are settings, not frames (MSBTProfiles.lua:84-120).
- `MSBTForeverMinimapButton` on the Minimap (Components/MinimapButton.lua:92).

## How a player starts it
- No installer: on unless turned off (`MSBTProfiles_SavedVars.userDisabled`, nil = on, MSBTProfiles.lua:2688-2697).
- `/msbt` opens its options; `/msbt disable` / `enable` (localized words: "disable" / "enable" in English, Locales/Locales.lua:34-35), `/msbt reset`, `/msbt version` (MSBTProfiles.lua:2954-3005, command MikSBT.lua:51).
- Its globals: `MikSBT`, with modules `MikSBT.Profiles` (MSBTProfiles.lua:2-4) and `MikSBT.Animations` (Display/AnimationEngine.lua:1-3).
- Many debug slash commands of its own (/msbtlog, /msbtfd, /msbtmeter...): leave them alone.

## What each part needs before it shows
- `MSBTAnimationFrame`: the addon on and a line to show: taking or dealing damage, heals, notices; a line's area not disabled (`scrollAreas.<name>.disabled`, Display/DisplayService.lua:146-148).
- Some of its readers stop in fights inside instances (arena, battleground, keystone, dungeon, raid: MikSBT.lua:20-42).

## Set up for a test
- by code: turned off -> `MikSBT.Profiles.SetOptionUserDisabled(false)` (what `/msbt enable` does, MSBTProfiles.lua:2688). Takes at once. It also sets its own "Blizzard damage" option off (`blizzardDamageEnabled`, already off by default on Forever, MSBTProfiles.lua:1116): the recipe puts both back after.
- by code: a line on screen -> `MikSBT.DisplayMessage(text, "Incoming", false, r, g, b)` (its public call, MSBTMain.lua:1048, Display/DisplayService.lua:133; colors 0-255). The recipe shows one in Incoming and one in Outgoing.
- by hand: real lines -> hit a mob, or let one hit you.
- out of reach: nothing needed.

## Surprises
- Its frame is hidden between lines: a frame check that wants it shown must make a line first (DisplayMessage, above) and look within a second or two.
- Everything is on one frame, so no row can hide just its incoming text (Support/MikScrollingBattleText.lua's note).
- Turning it on also switches its "Blizzard damage" option off (MSBTProfiles.lua:2690-2692).
- Its options' reset sets `blizzardDamageEnabled` on and the addon off (`ResetOfficialBlizzardCombatText`, MSBTProfiles.lua:2663).
