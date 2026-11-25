# BattleTextForever

Version read: v1.43.0 (_forever_), 2026-11-25 (code read, not yet proven by a run of the recipe). Support/BattleTextForever.lua was read from 1.29.0.

## What it is
Scrolling combat text: your hits and heals, the damage you take, and notices (loot, XP, kills).
- Four text areas, made at login, always shown (only their lines come and go): `BattleTextForeverIncoming`, `BattleTextForeverOutgoing`, `BattleTextForeverHealing`, `BattleTextForeverNotifications` (Display.lua:134-140, labels Core.lua:233-237).
- `BattleTextForeverPlates`: holds your hit lines over enemy nameplates, when its Layout tab sends them there (Display.lua:174).
- `BattleTextForeverStart`: a secure "Start BattleText" button at the top of the screen, only after a fight where it got no combat log lines (Notices.lua:253, :367).
- `BattleTextForeverMinimapButton` on the Minimap (Settings.lua:494), on by default (`minimap`, Core.lua:156).

## How a player starts it
- No installer: on at login (`enabled = true`, Core.lua:84). A chat line says "loaded. Type /btf for options." (Settings.lua:684).
- `/btf` or `/battletext`: options; `/btf on` / `off`, `test`, `lock` / `unlock`, `reset` (Settings.lua:561-600).
- The global is `BattleTextForever` (its table BT, Settings.lua:559).
- Settings in `BattleTextForeverDB`, or the character's own copy in `BattleTextForeverCharDB.settings` when `BattleTextForeverCharDB.own` is true (Settings.lua:49, :651-663). `BattleTextForever.db` is whichever is live.

## What each part needs before it shows
- Each area: the addon on (`db.enabled`) and something to show: you hit something (Outgoing), get hit (Incoming), heal or get healed (Healing), loot / gain XP / kill (Notifications). Lines are drawn only while on or testing (Display.lua:601).
- Plates: Layout tab's "Enemy nameplates" route for your hits.
- Start button: a fight you acted in that brought no combat log line (Notices.lua:376-389).

## Set up for a test
- by code: turned off -> `BattleTextForever.db.enabled = true; BattleTextForever:ApplySettings()` (what `/btf on` does, Settings.lua:579-581). Takes at once, no reload. The recipe does this and turns it off again after.
- by code: lines in all four areas -> `BattleTextForever:Test()` (Settings.lua:435): 13 sample lines 0.3 s apart, shown even while off. The recipe calls it.
- by hand: real lines -> hit a mob, or let one hit you.
- out of reach: nothing needed.

## Surprises
- `hideBlizzard` is off by default in 1.43.0 (Core.lua:158): it only turns the game's floating text off when that option is on. Support/BattleTextForever.lua's top comment says it turns it off (true of an older version?).
- Support/BattleTextForever.lua's `theirs` reads `BattleTextForeverDB.enabled`, but a character with its own settings uses `BattleTextForeverCharDB.settings.enabled` instead; `BattleTextForever.db.enabled` is the live one.
- It turns the game's combat log lines on every 3 s (`C_CombatLog.SetFilteredEventsEnabled(true)`, Settings.lua:682, Notices.lua:229).
- The Start button's click is a macro that clicks ChatFrame2Tab and back (Notices.lua:305-335): under a chat addon that hides the tabs it can't work (it says so).
- Unlocked (`/btf unlock`), each area shows a box with a header bar to drag (Display.lua:143-163, :258).
