# DaylightUI

Version read: _forever_ v2.2.7 and _retail_ v1.9.5 (both interface 16001), 2026-11-25 (code read, not yet proven by a run of the recipe)

File:line below is the _forever_ copy unless it says retail. The levers the
recipe uses are in both copies (checked: the same defaults, the same
functions, the same frame names).

## What it is
A whole-UI suite: a core (`DaylightUI`, global `DaylightUI`, Core.lua:7) and one addon per part
(ActionBars, Bags, Buffs, Chat, InfoPanel, Nameplates, QoL, Quests, Skins, Tooltip, UnitFrames;
AuctionHouse only on _forever_). Each part registers a module with the core (`DaylightUI:RegisterModule`,
e.g. DaylightUI_QoL/Module.lua:14) and is turned on at PLAYER_LOGIN (Core.lua:787, 1014). The parts the
Advanced Frames rows cover (Support/DaylightUI.lua):
- `DaylightUIDamageMeter`: the damage meter's own window, only when the meter is detached (DaylightUI_InfoPanel/Panel.lua:118). Docked, the meter sits inside the info panel (Minimap row).
- `DaylightUIMeterWindow_<id>`: meter windows the player adds (MeterFrame.lua:182).
- `DaylightUIThreatMeterFrame`: the threat meter's own window, used only with `threat.at = "free"` (ThreatMeter.lua:658). Otherwise the threat meter hangs on the info panel and this frame stays empty.
- `DaylightUIFlightTimer`: destination and time left on a flight path (DaylightUI_QoL/Flight.lua:295).
- `DaylightUILootFeed`: loot ribbons at the bottom right (DaylightUI_QoL/LootFeed.lua:983).
- `DaylightUIBuffReminderHolder`: missing-buff reminder on a ready check or entering a dungeon (DaylightUI_Buffs/Reminder.lua:247).
- `DaylightUIPullTimer`: a pull countdown (DaylightUI_UnitFrames/Pull.lua:179).
- `DaylightUIQuestArrow`: TomTom-style arrow (DaylightUI_Quests/Arrow.lua:261).
- `DaylightUIQuestMarker`: its in-world marker over the game's (DaylightUI_Quests/Nav.lua:161).
- `DaylightUIQuestProgress`: its "slain 5/8" lines (DaylightUI_Quests/Progress.lua:129).
- `DaylightUIDataBar`: a data bar along the bottom (DaylightUI_InfoPanel/DataBar.lua:103).
- `DaylightUICursorRing`: a ring round the mouse (DaylightUI_QoL/CursorRing.lua:242).
- `DaylightUILeaderTab`: group leader tab on the screen's left edge (DaylightUI_UnitFrames/Leader.lua:507).

## How a player starts it
- Setup guide (`DaylightUIInstaller`) shows 1 s after login on a character with no saved answer (Installer.lua:104-108). Its welcome's "Play now" finishes with one reload (InstallerSteps.lua:192). Closing it with its X undoes its previews and it asks again next login (Installer.lua:1265).
- Saved flag: `DaylightUIDB.characters[<char>].install` = "installed" (or "skipped" from the old installer) (Installer.lua:51-52, DB.lua:349). Read it with `DaylightUI.Installer.State()`.
- Until it's finished the character runs on an unsaved stand-in profile: every change is dropped at logout (DB.lua:935-937).
- Slash: `/dui` opens its options (Options/Panel.lua:1226), `/dui install` the setup guide, `/dui test` test mode (Core.lua:973), `/dui leader test` leader practice, `/dui unlock` mover mode. Also `/rl`, `/cdm`, `/kb`, `/bl`.

## What each part needs before it shows
- Damage meter window: `meter.enabled` (on) and `meter.detached` (off by default) (InfoPanel/Defaults.lua:39-41, Panel.lua:63-73). Options label "Separate damage meter window" (MeterOptions.lua:470).
- Meter windows: the player adds one ("New window", MeterOptions.lua:264); none by default.
- Threat window: `threat.at = "free"` (default "left", Defaults.lua:88), then a fight in a group or with a pet (`auto = "group"`), or test mode (ThreatMeter.lua:72-77).
- Flight timer: a flight (on by default, QoL/Defaults.lua:141), or test mode (Flight.lua:517).
- Loot feed: looting something (on by default, QoL/Defaults.lua:119), or test mode (LootFeed.lua:937).
- Buff reminder: a ready check or entering a dungeon or raid with buffs missing (`reminder.enabled` on, Buffs/Core.lua:121), or test mode (Reminder.lua:402-409).
- Pull timer: a countdown (START_PLAYER_COUNTDOWN, Pull.lua:165), `pull.enabled` on (UnitFrames/Defaults.lua:212). Gone after the count.
- Quest arrow: `nav.arrow` (off by default, Quests/Defaults.lua:68). Shown once on; points via QuestieDB spots or the game's marker (Arrow.lua:1-8, 455-471).
- Quest marker: `nav.marker` (off by default, Quests/Defaults.lua:63). Shown once on, alpha 0 until the game has a navigation frame (a quest picked) (Nav.lua:374-381, 475-492).
- Quest progress: a quest objective's progress (`progress` on, Quests/Defaults.lua:59), or test mode (Progress.lua:315).
- Data bar: `databar.enabled` (off by default, InfoPanel/Defaults.lua:120; DataBar.lua:236-240).
- Cursor ring: `cursorRing` (off by default) and `cursorRingWhen = "always"` (QoL/Defaults.lua:103-104, CursorRing.lua:55-60).
- Leader tab: in a group as leader/assist, or test mode with the party or raid sample (Leader.lua:117-120, 162-167).

## Set up for a test
- by code: `DaylightUI:GetModule(name).db` is the module's table in the active profile (Core.lua:747, 798; DB.lua:961). The recipe writes it there and calls the module's own `OnSettingChanged` (QoL/Module.lua:24, InfoPanel/Module.lua:15, Quests/Module.lua:44 with the path) out of fights. Applies at once, no reload.
  - QoL `cursorRing = true`, `cursorRingWhen = "always"` -> cursor ring.
  - InfoPanel `databar.enabled = true` -> data bar; `meter.detached = true` -> damage meter window; `threat.at = "free"` -> threat window.
  - Quests `nav.marker = true`, `nav.arrow = true` -> marker and arrow.
- by code: `DaylightUI.SetTestMode(true)` (Core.lua:955, what `/dui test` does) -> samples in flight timer, loot feed, threat, meter, buff reminder, leader tab (with the party sample), quest progress, data bar texts. Not in a fight; a fight ends it (Core.lua:967). Its tick box hides parts per account in `DaylightUIDB.testHidden` (TestBox.lua:30-39): the recipe clears ours and puts them back.
- by code: `C_SuperTrack.SetSuperTrackedQuestID(id)` (game API) picks a quest from the log so the game has a marker for its marker and arrow.
- by code (a test step, not the recipe): `DaylightUI.RunCommand("leader test party")` -> practice ready check, then 5 s later a 10 s sample pull timer (Leader.lua:753-819, 856). It swaps full test mode for the party sample only (TestBox.lua:56-68).
- by hand: a meter window: type /dui, click Info Panel, click Meters, click New window, pick Damage. Remove it later with its Delete (click twice).
- by hand: its setup guide up -> close it with its X (or "Play now" then Reload, to set the character up for good).
- out of reach: adding a meter window (`ns.Windows.Add`), the pull timer's `Pull.Start`, the installer's Finish: all in the parts' private tables.

## Surprises
- `DaylightUI:Set(...)` on a character not set up turns its stand-in into a real profile and marks the character "installed" (DB.lua:942-950 fires ProfileKept, Installer.lua:94-96); its next login then puts its Edit Mode layout in place with a reload. The recipe never calls `Set`: it writes the module table directly.
- Test mode, unlock mode and its options window (on the page of an area) force its fade areas to full (Fade.lua:166-182). Cinematic's rows hook alpha, but a row test reading DaylightUI's own fade can see it pinned. Close its options before a run.
- Test mode puts its tick box at the top of the screen (TestBox.lua:301-309) and sample unit frames everywhere.
- The data bar reserves room at the bottom: its other frames move up while it's on (Panel.lua:1118).
- The quest marker hides the game's own marker pieces (alpha 0) while on (Nav.lua:15-18).
- The threat window frame is always shown, empty unless `at = "free"`.
- Its parts can be turned off per character (each is its own addon): the recipe skips a part that isn't up.
