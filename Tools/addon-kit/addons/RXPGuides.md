# RXPGuides (RestedXP Guides)

Version read: v4.11.40 (_forever_, one copy for every client), 2026-11-25 (code read, not yet proven by a run of the recipe)

## What it is
A leveling guide: steps to follow, with a waypoint arrow toward the next place. Its folder is RXPGuides (the name the addon kit and Support/RestedXP.lua's rows use).
- Guide window `RXPFrame` (GuideWindow.lua:24): a top bar with the guide's name, the current step, a step list, a footer. Stands in for the game's quest tracker.
- Waypoint arrow `RXPG_ARROW` (map.lua:41).
- Quest item window `RXPItemFrame` (an AceGUI frame put on `_G`, ActiveItemFrame.lua:207-213).
- Target window `RXPTargetFrame` ("Active Targets", Targeting.lua:830-836) with buttons `RXPTargetFrame_EnemyButton<n>` / `_FriendlyButton<n>` (Targeting.lua:1110, :1191).
- Level splits: an AceGUI frame with no name (LevelingTracker.lua:995-1003).
- Map and minimap pins, flight timers.

## How a player starts it
- No installer. A fresh level 1 character gets a default guide by itself (`addon.SelectDefaultGuide`, GuideLoader.lua:965-974: only at level 1). Anyone else sees "Welcome to RestedXP Guides / Right click to pick a guide" on the guide window's top bar (`addon.emptyGuide`, GuideWindow.lua:1605-1612).
- Picking a guide: right-click the top bar (GuideWindow.lua:1503-1508) -> a menu of guide groups (on Forever "RestedXP Forever Guide (A)" / "(H)", Guides/forever/*.lua `#group`) -> click a guide (GuideWindow.lua:2443-2452).
- `/rxp`, `/rxpg`, `/rxpguides` (SettingsPanel.lua:315-317, AceConsole: `SlashCmdList.ACECONSOLE_RXP`): alone = options; `show` / `hide` / `toggle` all flip its on/off switch `showEnabled` (SettingsPanel.lua:114, :3791); `splits` flips the level splits; `import`, `debug`, `bug`, `preview`, `help`.
- Options: `/rxp`, its minimap button, or the cog on its footer.

## What each part needs before it shows
- Guide window: `showEnabled` (true) and not `hideGuideWindow` ("Hide Window", off) (RXPGuides.lua:1606-1607, SettingsPanel.lua:744-756). Its classic window only: with `enableBetaFeatures` + `enableV2Interface` (both off) it uses its V2 windows instead (UI/V2/Core.lua:1498-1502), which our rows don't name.
- A guide: kept per character in `RXPCData.currentGuideName` / `currentGuideGroup` (GuideWindow.lua:1931-1933); "" while none is loaded.
- Arrow: a current step that goes to a place, `disableArrow` ("Hide waypoint arrow") off, `showEnabled`, outside instances (map.lua:66, :1046-1050, :1223-1252).
- Quest item window: a current step with a usable item in your bags, `disableItemWindow` off (ActiveItemFrame.lua:216, :375-379).
- Target window: a current step with mobs or NPCs to target, `enableTargetFrame` on (true) (Targeting.lua:843-849).
- Level splits: `enablelevelSplits` ("Enable Level Splits"), off to start with (not in its defaults, SettingsPanel.lua:128-260), and `enableTracker` (true) at login (LevelingTracker.lua:62).

## Set up for a test
- by code: its saved settings are the AceDB table `RXPSettings` (SettingsPanel.lua:275): `RXPSettings.profiles[RXPSettings.profileKeys["Name - Realm"]]` is the live profile its code reads.
- by code: switched off -> `SlashCmdList.ACECONSOLE_RXP("show")` (flips it; call it only when off). The recipe does this and switches it off again after (Dev/RXPGuidesSupportTest.lua).
- by code: Hide Window on -> profile `hideGuideWindow = false` + `RXPFrame:Show()`, as its option does (SettingsPanel.lua:750-756). The recipe does this and puts it back.
- by hand: no guide -> right-click the guide window's top bar, point at RestedXP Forever Guide (A) or (H), click any guide. Saved per character, so once per character.
- by hand: arrow hidden -> right-click a step that says to go to a place, click Go to step (GuideWindow.lua:2048-2058, :1577-1582).
- by hand: item / target windows -> be on a step that uses an item / names a mob (they come and go with the steps).
- by hand: level splits -> `/rxp`, tick Enable Level Splits.
- out of reach: `addon:LoadGuide`, `addon.SetStep`, `addon.UpdateArrowData`, `addon.tracker.splits` are in its private addon table (`_G.RXPGuides` holds only `RegisterGuide` and `talents`, GuideLoader.lua:1390, Talents.lua:1415). Setting `disableArrow` in the profile alone doesn't bring the arrow back till its next arrow update, so the recipe leaves it as a reason.

## Surprises
- Its splits frame has no name: `RXPLevelSplits` (Support/RestedXP.lua's rxpSplits row) isn't made anywhere in this version (no match in its code), so that row finds nothing as it stands.
- `/rxp show` and `/rxp hide` both flip the switch (SettingsPanel.lua:114): sending "show" while it's on switches it off.
- Its arrow sets its own alpha (`af:SetAlpha`, map.lua:113) and its guide window fades itself on mouseover settings: hooked (`hookAlpha`).
- Its item window is secure (`IsFeatureEnabled` returns secure = true, ActiveItemFrame.lua:217): it won't show or hide in a fight.
- It hooks ToggleAllBags / ToggleBag / ToggleQuestLog after the game's (declared in Support/RestedXP.lua).
