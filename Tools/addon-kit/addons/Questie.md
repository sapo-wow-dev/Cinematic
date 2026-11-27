# Questie

Version read: 12.14.0 (_forever_), 2026-11-25 (the tracker recipe proven q7fb4: ready PASS, addon kit 0 FAIL)

## What it is
A quest helper: it marks where each quest's objectives, givers and turn-ins are.
- Its quest tracker (`Questie_BaseFrame`, with `Questie_HeaderFrame` "Questie Tracker: n/40" and pooled lines `linePool1..250`), standing in for the game's.
- Quest item buttons `Questie_ItemButton1..40`, beside or in the tracker lines.
- Map icons: `QuestieFrame*` on the world map and on the minimap (named Buttons straight on the Minimap, through its HereBeDragons copy; `QuestieFrameGroup` is made but unused). They're pins, not addon buttons: they fade with the Minimap row. Our Minimap Reveal ("Use Questie DB") reads the minimap ones (Support/QuestieMinimap.lua).
- Objective icons on nameplates and on the target frame (`nameplateEnabled`, `nameplateTargetFrameEnabled`, both on to start with).
- Extra lines in mob and item tooltips (its QuestieTooltips module).

## How a player starts it
- Needs its database addon QuestieDB (and QuestieTrace) loaded too.
- First login on Forever: a "Welcome to Questie" window (`QuestieTutorialChooseObjectiveType`) asks for an objective style: Questie Objectives / pfQuest Objectives / Blizzard Objectives. Saved as `Questie.db.global.tutorialObjectiveTypeChosen` (Modules/Tutorial/Tutorial.lua:10, ChooseObjectiveType.lua:80). Nothing else waits on it.
- `/questie` (also `/questieclassic`, `/q`) opens its options (Modules/QuestieSlash.lua:35-37); its minimap button too.
- `/questie tracker show` / `hide` turn its tracker on / off and reload (QuestieSlash.lua:118-122 -> QuestieTracker.lua:577-590); `/questie tracker` alone flips `trackerEnabled` without a reload (QuestieTracker.lua:593).

## What each part needs before it shows
- Tracker: `trackerEnabled` (default true, Modules/Options/QuestieOptionsDefaults.lua:181), and a tracked quest, or `alwaysShowTracker` (default false, :119) with nothing tracked (Modules/Tracker/QuestieTracker.lua:1007-1016).
- Tracked: every quest in your log to start with (`autoTrackQuests` true, :88); untracked ones sit in `Questie.db.char.AutoUntrackedQuests` (QuestieTracker.lua:1187-1197).
- Open (lines shown): `Questie.db.char.isTrackerExpanded` (default true, :246). In instances it folds itself up (`minimizeTrackerInInstances` true, :101) or hides with `hideTrackerInInstances` (false, :103) (QuestieTracker.lua:690-725).
- Item buttons: a tracked quest with a usable item.
- Minimap icons: `enableMiniMapIcons` and `enableAvailable` (both true, :82, :66), and a quest giver with a quest for you near enough to fall on the minimap.

## Set up for a test
- by code: no quest tracked -> `C_QuestLog.AddQuestWatch(questID)` on a quest from your log; Questie hooks it and tracks it (QuestieTracker.lua:1261-1267, :1430-1437). Undo: `C_QuestLog.RemoveQuestWatch(questID)`, which it hooks to untrack (:1269-1279). The recipe does both (Dev/QuestieSupportTest.lua).
- by code: folded up -> `QuestieLoader:ImportModule("QuestieTracker"):Expand()` / `:Collapse()` (QuestieTracker.lua:605-625; QuestieLoader is global).
- by code: `Questie.db.profile.trackerEnabled = true` + a reload, when a player turned it off.
- by code (not used by the recipe now): `Questie.db.profile.alwaysShowTracker = true` + the tracker module's `:Update()` shows it with nothing tracked (header only).
- by hand: step outside an instance; with an empty quest log, accept any quest.
- by hand: item buttons need a quest that has a usable item; minimap icons need you near a quest giver with a "!" (any starting zone town).
- out of reach: nothing needed for the tracker.

## Surprises
- With its tracker on, it hides the game's `ObjectiveTrackerFrame` (`Questie.lua:51` -> `Modules/QuestieCompat.lua:404`). On Forever, when the game shows its tracker again in combat, Questie holds it at alpha 0 until the fight ends, then hides it (QuestieCompat.lua:375-381, hooked OnShow :409). We follow that alpha (`ns.FollowOwnAlpha`, Support/Questie.lua) rather than writing ours over it.
- It hooks `StaticPopup_Show` with `hooksecurefunc` (`Modules/EventHandler/QuestEventHandler.lua:135`): the global is a new function, but hooks from before (ours, QoL/Reload.lua) still run first. The addon kit reads it as "replaced" (declared).
- Its tracker is made seconds after login, hidden, and shown about a second later (Support/Questie.lua snaps it).
- `/questie tracker hide` (its `Disable`) also wipes its tracked lists (QuestieTracker.lua:586-587): never send it from a test.
- It hides its tracker when every tracked quest is done, if "show complete quests" is off (TrackerUtils.lua:1311-1322; on to start with).
