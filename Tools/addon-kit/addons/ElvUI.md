# ElvUI

Version read: v16.02, the _forever_ copy (ElvUI, ElvUI_Libraries, ElvUI_Options; its tocs list every client), 2026-11-25 (code read, not yet proven by a run of the recipe)

Paths below are under `ElvUI/Game/Shared/` unless they start with another folder.

## What it is
A whole-UI replacement: its own frames in place of most of the game's.
- Unit frames (`ElvUF_Player`, `_Pet`, `_PetTarget`, `_Target`, `_TargetTarget`, `_TargetTargetTarget`, `_Focus`, `_FocusTarget`, `_Party`, `_Raid1-3`, `_Tank`, `_Assist`, `_Raidpet`, `_Arena1-5`), with their power and cast bars (`ElvUF_Player_PowerBar`, `ElvUF_Player_CastBar`...).
- Action bars `ElvUI_Bar1`-`10` and `13`-`15` (Modules/ActionBars/ActionBars.lua:2050-2056), pet bar `ElvUI_BarPet`, stance bar `ElvUI_StanceBar`, totem bar, vehicle leave button, micro bar `ElvUI_MicroBar` (Modules/ActionBars/MicroBar.lua:65), bag bar `ElvUIBagBar` (Modules/Bags/BagBar.lua:316).
- Buffs and debuffs `ElvUIPlayerBuffs` / `ElvUIPlayerDebuffs`.
- Data bars: experience, reputation, pet experience, honor, azerite, threat (`ElvUI_ThreatBar`, in `ElvUI_ThreatBarHolder`; Modules/DataBars/Threat.lua:129), each in a `<name>Holder`.
- Chat panels `LeftChatPanel` / `RightChatPanel` with their tabs, data texts and toggle buttons.
- Cosmetic panels `ElvUI_TopPanel` and `ElvUI_BottomPanel` (Layout/Layout.lua:44).
- Nameplates (its own frame on each game plate) and its player plate `ElvNP_Player` (Modules/Nameplates/Nameplates.lua:1107).
- Its AFK screen `ElvUIAFKFrame`, its minimap backdrop, its tooltips and chat bubbles look.

## How a player starts it
- First login: its install window "ElvUI Installation" (`ElvUIInstallFrame`, strata TOOLTIP, 550x400 in the middle; General/Install.lua:1446-1658). It opens at login when `E.private.install_complete` is empty (General/Core.lua:2074), and again after a profile change (Core.lua:1746). Nine pages: Continue / Previous at the bottom, an X at the top right.
- The saved flag: `E.private.install_complete` (= `ElvPrivateDB`, per character), set to ElvUI's version by `E:SetupComplete()` (Install.lua:1199). The X at its top right calls `E:SetupComplete()` and hides the window, no reload (Install.lua:1630-1635): that's the skip. Page 9's Finished button does the same and reloads (Install.lua:1422). Page 1 says "Press the button below if you wish to skip" but shows no button in this version: the X is the only skip.
- Profile: page 4 of the installer offers Shared Profile ("Default") or New Profile; settings live in `ElvDB` (profiles, `E.db`) and `ElvPrivateDB` (per character, `E.private`).
- Slash commands (General/Commands.lua:210-237): `/ec` or `/elvui` open its options (ElvUI_Options, load on demand); `/emove` or `/moveui` its movers; `/kb` key binds; `/estatus`; `/resetui`.
- Global: `ElvUI` = { E, L, V, P, G } (General/Initialize.lua:71-75); `E = ElvUI[1]`. Its modules hang on E: `E.ActionBars`, `E.Layout`, `E.DataBars`, `E.NamePlates` (Initialize.lua:77-92), each `module.db = E.db[<its part>]` (Initialize.lua:662).

## What each part needs before it shows
- Every part: its module on in `E.private` (`actionbar`, `unitframe`, `nameplates`, `chat`, `auras`, `bags` `.enable`, all on by default; Defaults/Private.lua:49-211). Changing one needs a reload (its options show "One or more of the changes you have made require a ReloadUI.", General/StaticPopups.lua:189).
- Action bars 1, 3, 4, 5: on by default (Defaults/Profile.lua:3502-3530). Bars 2, 6, 7, 8, 9, 10, 13, 14, 15: OFF by default (`AB_Bar.enabled = false`, Profile.lua:3396). `E.db.actionbar.barN.enabled`, applied by `AB:PositionAndSizeBar("barN")` (Modules/ActionBars/ActionBars.lua:292, show/hide at :399-409; secure, so out of fights). Empty buttons still draw (`showGrid = true`).
- Micro bar: OFF by default (`E.db.actionbar.microbar.enabled`, Profile.lua:3343), applied by `AB:UpdateMicroButtons()` (MicroBar.lua:356; its visibility waits out a fight, :275).
- Pet bar: a pet (its visibility `[pet,...] show`, Profile.lua:3383-3392). Stance bar: a class with stances. Totem bar: a shaman with totems.
- Bag bar: OFF by default and private (`E.private.bags.bagBar = false`, Private.lua:51): needs a reload.
- Top panel: OFF by default (`E.db.general.topPanel`, Profile.lua:79), applied by `E.Layout:UpdateTopPanel()` (Layout.lua:66). Bottom panel: on by default (Profile.lua:80).
- Threat bar: on (`E.db.databars.threat.enable`), but it only fills in combat, with a target, and with a pet or in a group (Threat.lua:53).
- Experience bar: on, hidden at max level (`hideAtMaxLevel`, Profile.lua:427). Reputation bar: OFF by default (Profile.lua:438), and it needs a watched faction (Modules/DataBars/Reputation.lua:56); applied by `DB:ReputationBar_Toggle()` + `DB:UpdateAll()` (as its option does, ElvUI_Options/Game/Shared/DataBars.lua:99). Pet experience: a hunter's pet below max level.
- Player plate `ElvNP_Player`: only with `E.db.nameplates.units.PLAYER.useStaticPosition` on (OFF by default, Profile.lua:1116), applied by `NP:ConfigureAll()` (Nameplates.lua:692, its `ToggleStaticPlate` :596). It turns the game's `nameplateShowSelf` CVar off while static (:611). Even then it shows in combat only by default (`visibility.showInCombat`, `showAlways = false`, Profile.lua:1127-1133).
- Target, target of target, focus, focus target: a target / a focus. Party: a group. Raid frames: a raid. Arena frames: an arena. Encounter power bar: an encounter or quest with its own power.
- AFK screen: you going AFK with `E.db.general.afk` on (on by default, Profile.lua:67).

## Set up for a test
- by code: the installer -> `E:SetupComplete()` + `E.InstallFrame:Hide()`, exactly what its X does (Install.lua:1630-1635). Undo: put `E.private.install_complete` back (empty = it shows again at the next login).
- by code: bars 2, 6-10 (13-15 on retail) -> `E.db.actionbar.barN.enabled = true` + `E.ActionBars:PositionAndSizeBar("barN")`, out of fights only.
- by code: micro bar -> `E.db.actionbar.microbar.enabled = true` + `E.ActionBars:UpdateMicroButtons()`, out of fights.
- by code: top panel -> `E.db.general.topPanel = true` + `E.Layout:UpdateTopPanel()`.
- by code: reputation bar -> `E.db.databars.reputation.enable = true` + `E.DataBars:ReputationBar_Toggle()` + `E.DataBars:UpdateAll()`.
- by code: player plate -> `E.db.nameplates.units.PLAYER.useStaticPosition = true` + `E.NamePlates:ConfigureAll()`, out of fights (it sets a CVar).
- All of those are `E.db` = the profile, which may be shared by every character on "Default": undone in putBack.
- by hand: a module turned off -> type `/ec`, click ActionBars (or UnitFrames, or Nameplates) on its left, tick Enable at the top, close the options, click Accept in "One or more of the changes you have made require a ReloadUI.".
- by hand: reputation bar content -> in the game's Reputation window, pick a faction and tick its "Show as Experience Bar".
- out of reach: the bag bar (private + reload), a focus (protected), a group, raid, arena, a pet, an encounter: states the generic test or the player makes.

## Surprises
- The installer reopens after any profile change (Core.lua:1746), not only at first login.
- Its frames set their own alpha all the time (bars' mouseover, unit frames' range fader with `E:UIFrameFade`): Support/ElvUI.lua hooks them.
- `/edebug on` turns off every other addon and reloads (Commands.lua:40-55); `/resetui` resets all movers: never from a test.
- If ElvUI and ElvUI_Libraries versions differ it shows an update box at login (Core.lua:2080).
- Its player plate turns the game's `nameplateShowSelf` off while static: putting the option back puts the CVar back too (ConfigureAll).
