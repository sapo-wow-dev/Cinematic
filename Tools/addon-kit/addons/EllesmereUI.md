# EllesmereUI

Version read: v9.9.4, the _forever_ copy installed 2026-11-25. Everything here comes from reading the code. None of it has been proven by a run of the recipe yet.

Paths are relative to the AddOns folder. The parts are separate folders: `EllesmereUI` (the core), `EllesmereUIQoL` (QoL), `EllesmereUIActionBars` (AB), `EllesmereUIResourceBars` (RB), `EllesmereUIAuraBuffReminders` (ABR), `EllesmereUIDataBars` (DB), `EllesmereUICooldownManager` (CDM), `EllesmereUIDamageMeters` (DM), `EllesmereUIMythicTimer` (MT), `EllesmereUIForeverEssentials` (FE), `EllesmereUIUnitFrames` (UF), and others we have no rows for.

## What it is
A suite that replaces the whole UI, with one addon per part. These are the parts we cover:
- Action bars 1-10 plus pet, stance and XP bars (`EABBar_*`). Bars 1-5 and pet, stance and XP fade with the game's rows; bars 6-10 have rows of their own.
- Unit frames (`EllesmereUIUnitFrames_*`) and player aura bars (`EllesmereUIPlayerAuraBars_*`). They fade with the HUD rows.
- QoL displays: Secondary Stats, FPS Counter, Movement Alert, Time Spiral, Gateway Shard, Crosshair, Target Distance, Self Combat Text, Cursor Circle, Trail, GCD and Cast rings, and Raid Tools windows. Battle Res and Bloodlust exist on retail only.
- Resource bars: GCD Bar, Totem Bar, Call Totem Bar.
- Buff reminders (`EABR_*` anchors).
- Damage meter windows (`EllesmereUIDMFrame<n>`), plus a spell history strip and bar, and a combat timer.
- Data bars (`EllesmereUIDataBarsBar<id>`).
- Cooldown manager bars (`ECME_CDMBar_<key>`, `ECME_TBBWrap<n>`).
- Mythic+ tools (MT): the key timer, kick bars, targeted spell bars, and target and focus cast bars. Retail only.
- WoW Forever Essentials (FE): Threat Meter, Junk List, Flight Timer, Loot Feed, Active Form. WoW Forever only.
- The AFK screen (core).

## How a player starts it
- **First login: the module picker.** It reads "FIRST TIME SETUP / Welcome to EllesmereUI" (EllesmereUI_FirstInstall.lua:215, 222) and shows 0.5 s after PLAYER_LOGIN (:586).
  - Its buttons are "Check All", "Uncheck All" and "Reload UI" (:242, 261, 407). Escape is disabled, so Reload UI is the only way out (:148).
  - Saved flag: `EllesmereUIDB.firstInstallPopupShown` (:444). It is set automatically for an account that already has profile data (:554).
- **Next login on WoW Forever: the look picker.** It reads "CHOOSE YOUR LOOK / How should EllesmereUI look?" (EllesmereUI_StyleChoicePopup.lua:113, 119). Its dimmer is named `EUIStyleChoiceDimmer`.
  - Saved flag: `EllesmereUIDB.styleChoicePending` (true means it is due). It is cleared by Stamp (:36).
  - The card marked "In Use", or Escape, closes it with no reload (:105-108, 133-140). Any other card reloads.
  - It shows at login +0.8 s only (:213-226). Clearing the flag while it is not up is safe.
- **Kick Tracker intro.** Retail only; it is stamped at login on WoW Forever (EllesmereUI_KickTrackerPopup.lua:392, 434). Flag: `EllesmereUIDB.kickTrackerIntroShown`.
- **Launch video intro.** Retired: it never fires (EllesmereUI_VideoGuides.lua:655).
- **Conflict popup.** "Incompatible Addon Detected", with the buttons "Okay" and "Don't show again". The second one sets `EllesmereUIDB.dismissedConflicts[addon]` (EllesmereUI.lua:3775, 3847).
- **Slash commands** (EllesmereUI.lua:3874-3976):
  - `/eui`, `/ellesmere`, `/ellesmereui` and `/ee` open or close its options. They refuse in fights.
  - `/unlock` opens Unlock Mode.
  - `/epm` opens its Party Mode page; `/partymode` toggles party mode.
  - `/euiraid` toggles Raid Tools.
  - `/euitm show|hide|test` drives the threat meter (FE).
  - `/rl` reloads.
- **Profiles.** Settings for every part except FE sit in `EllesmereUIDB.profiles[EllesmereUIDB.activeProfile or "Default"].addons.<folder>`, merged with defaults by `EllesmereUI.Lite.NewDB` (EllesmereUI_Lite.lua:250-290). Each part's own `...DB` global is wiped and never used.
  - FE keeps its settings account-wide in `EllesmereUIDB.<feature>` (FE.lua:15-45). A missing key reads as its default.
- **Reaching it from outside.**
  - The global `EllesmereUI` table.
  - `EllesmereUI.Lite.GetAddon(name, true)` returns a part's object; for example ActionBars gives `.db.profile`.
  - `EllesmereUI._ModuleNS[folder]` is each part's private ns, made public. For example `DamageMeters.ApplySpellHistory` and `DataBars.CreateBar` / `DeleteBar`.
  - Many globals of the form `_G._X_Apply`.

## What each part needs before it shows
- **Action bars 6-8:** on by default.
- **Action bars 9-10:** `bars.Bar9/Bar10.barVisibility = "never"` and `alwaysHidden = true` by default (AB EllesmereUIActionBars.lua:771-778). Turning them on means setting "always" / false, then `_G._EAB_Apply()` (AB EUI_ActionBars_Init.lua:66), out of fights.
- **Unit frames:** on, except `enabledFrames.focustarget = false` (UF EllesmereUIUnitFrames.lua:1403). Target, ToT, focus and pet need that unit to exist.
- **Player aura bars:** off by default; the master switch `playerAuraBars.enabled` is nil (UF EUI_PlayerAuraBars_Bars.lua:627-638).
- **Secondary Stats / FPS Counter:** `showSecondaryStats` / `showFPS` have no default (nil, off).
  - Both are read with `EllesmereUI.QoLExtrasGet`, which falls back to the root `EllesmereUIDB[k]` (QoL EllesmereUIQoL.lua:55-65).
  - FPS is drawn inside the stats block when `fpsAttachToStats` is on (:2948-2955).
  - Apply calls: `EllesmereUI._applySecondaryStats()` (:2757) and `EllesmereUI._applyFPSDisplay()` (:2985).
- **Crosshair:** `cursor.crosshairSize` is nil, read as "None" (:3716). The values are Thin, Normal and Thick (:3678). Apply with `EllesmereUI._applyCrosshair()`.
- **Target Distance:** `targetDistanceEnabled` is nil, and a target is also needed. Apply with `EllesmereUI._applyTargetDistance()` (:5003). The frame is unnamed; it is found by unlock key `EUI_TargetDistance`.
- **Self Combat Text:** `selfCombatText.enabled = false` (QoL EllesmereUIQoL_SelfCombatText.lua:34). Text only appears on hits. Apply with `EllesmereUI._applySelfCombatText()` (:441).
- **Cursor Circle:** on (`cursor.enabled = true`, QoL EllesmereUIQoL_Cursor.lua:1290).
- **Cursor Trail:** `trail = false` (:1325). Apply with `_G._ECL_ApplyTrail`.
- **GCD ring:** `gcd.enabled = false` (:1300). Apply with `_G._ECL_ApplyGCDCircle`.
- **Cast ring:** `castCircle.enabled = false` (:1312). Apply with `_G._ECL_ApplyCastCircle`.
- **Raid Tools:** `raidTools.mode = "never"` (QoL EllesmereUIQoL_RaidTools.lua:454). It shows with a group by a secure state driver, and stays hidden from a raid member who is not leader or assist.
  - `_G._EUI_RaidTools_Preview(true)` (:2320) shows the windows expanded with no group. `false` ends it.
  - With the default `showAs = "one"`, the markers sit inside the Group window, so `EllesmereUIRaidToolsMarkers` is not made. The icon shows only when folded up.
- **Movement Alert:** `movementAlert.enabledClasses = nil`, and a known movement spell must be on cooldown (QoL EllesmereUIQoL_MovementAlert.lua:235, 1838).
- **Time Spiral:** `tsEnabled = false`, and needs a proc.
- **Gateway Shard:** `gwEnabled = false`, and needs item 188152 in the bags (a warlock).
- **Battle Res / Bloodlust:** retail only. They need an M+ key or a raid boss fight. Each has a preview hook: `_G._EUI_BattleRes_SetPreviewOwner(f)` and `_G._EUI_Bloodlust_SetPreviewOwner(f)`.
- **GCD Bar:** `gcdBar.enabled = false` (RB EUI_ResourceBars_Defaults.lua:384). It shows during a GCD, or always with `alwaysShow`. Apply with `_G._ERB_Apply()`.
- **Totem Bar:** `totemBar.enabledClasses = nil` (:520), and a totem must be down (shaman).
- **Call Totem Bar:** `callTotemBar.enabled = false`. Shaman on WoW Forever only.
- **Buff reminders:** on (`display.remindersEnabled`). Something must actually be missing.
  - They hide while its options are open, when resting, in a vehicle, when flying, or when dead (ABR Refresh.lua:1914-1948).
  - The combat anchor shows in fights only. The cursor anchor needs `display.cursorAttach`.
  - Raid buffs default to off in the open world (ABR Defaults.lua:128).
  - The talent and beacon anchors never exist on WoW Forever.
- **Damage meters:** window 1 is on and always shown (DM EllesmereUIDamageMeters.lua:73, 170).
  - The spell history bar and strip are off: `dm.spellHistory.barEnabled` / `iconEnabled` (DM SpellHistory.lua:32-33). Apply with `_ModuleNS.EllesmereUIDamageMeters.ApplySpellHistory()`. The strip stays empty until something is cast.
  - The combat timer is off (`dm.standaloneTimer`, :135). It shows in fights only. Apply with `_G._EDM_Apply()`.
- **Data bars:** none by default (DB EllesmereUIDataBars.lua:216). Make one with `_ModuleNS.EllesmereUIDataBars.CreateBar("empty")` (:3123), remove it with `DeleteBar(id)` (:3199).
- **CDM bars:** cooldowns, utility and buffs are on (CDM EllesmereUICooldownManager.lua:660-729). It sets the game's `cooldownViewerEnabled` itself (CDM EUI_CDM_Lifecycle.lua:556).
  - Tracked buff bars: none by default, and each needs a spell picked.
- **Mythic+ tools:** `AllowLoadGameType: standard`, so they never load on WoW Forever.
  - On retail the key timer needs a key, and kick bars need a dungeon or arena.
  - Targeted, target and focus cast bars are off by default (`tsb.enabled`, `tfb.target.enabled` and `tfb.focus.enabled` are false). All of them preview in Unlock Mode.
- **Threat Meter:** `EllesmereUIDB.threatMeter.enabled = false` (FE ThreatMeter.lua:44). It needs an attackable target with a threat list, which means a fight. Apply with `EllesmereUI._ThreatMeter.Apply()`; `.Preview()` gives 10 s of sample rows.
- **Junk List:** `junkList.enabled = false` (FE JunkItems.lua:28). With no junk it reads "No junk items". Apply with `EllesmereUI._JunkItems.Apply()`.
- **Flight Timer:** on (`flightTimer.enabled = true`). Shows only on a taxi flight.
- **Loot Feed:** `lootFeed.enabled = false` (FE LootFeed.lua:31). Rows appear on loot. `EllesmereUI._LootFeed.Apply()` / `.Preview()`.
- **Active Form:** `activeForm.enabled = false` (FE ActiveForm.lua:15). Warrior, druid, paladin and hunter only, with a stance, form, aura or aspect up. Apply with `EllesmereUI._ActiveForm.Apply()`.
- **AFK screen:** `EllesmereUIDB.partyModeAfk` is nil (off). It shows only while you are /afk and out of fights (core EllesmereUI_PartyMode.lua:1082-1096). Run `EllesmereUI_UpdateAfkScreen()` after changing it.

## Set up for a test
The recipe is in Dev/EllesmereUISupportTest.lua.

**By code:**
- If the look picker's flag is set but the picker is not up, it clears `styleChoicePending`.
- It turns on, through each option's own apply call with no reload, and puts back after:
  - Secondary Stats
  - FPS Counter (detached from the stats)
  - Crosshair (Normal)
  - Target Distance
  - Self Combat Text
  - Cursor Trail, GCD and Cast rings
  - GCD Bar (Always Show)
  - Action Bars 9 and 10 (out of fights)
  - Spell History bar and strip
  - Combat Timer
  - AFK screen
  - Threat Meter, Junk List, Loot Feed (with its samples) and Active Form (WoW Forever)
- It opens the Raid Tools preview (out of fights).
- `ready()` waits for the frames among these that show without a state: Secondary Stats, FPS, Crosshair, Bars 9/10, Spell History bar, Junk List and Raid Tools.

**By hand:**
- First install: in "Welcome to EllesmereUI", click Reload UI, then run the test again.
- Look picker up: click the card marked In Use, or press Escape.

**Out of reach, or left alone:**
- Closing the module picker: its Close is local, and it always reloads.
- Player aura bars: `_ModuleNS.EllesmereUIUnitFrames.PAB_SetEnabled(true)` builds them, but it hides the game's buffs until a reload (UF EUI_PlayerAuraBars_Lifecycle.lua:60-80). Left off.
- Data bars and tracked buff bars: not made by the recipe. They would add saved bars.
- States the recipe doesn't wait for, each needing you to be somewhere or do something:
  - a fight: threat meter, combat timer, buff reminders' combat anchor
  - a target or focus: target distance
  - a flight: flight timer
  - /afk: AFK screen
  - a shaman with totems: totem bars
  - a class with a form: active form
  - a movement spell on cooldown: movement alert
  - anything missing: buff reminders
  - a group: Raid Tools without its preview
  - retail only: Mythic+ tools, Battle Res and Bloodlust

## Surprises
- Its parts set their frames' alpha all the time (visibility passes, mouseover, fights). Support/EllesmereUI.lua hooks those.
- Self Combat Text, while on, hides the game's CombatText frame (QoL EllesmereUIQoL_SelfCombatText.lua).
- QoL "extras" settings read the account root `EllesmereUIDB[k]` when the profile has nil. Write explicit values.
- Buff reminders hide while its options window is open. Don't open it during a reminder test.
- Raid Tools' preview ends when any other QoL options page is opened.
- Several frames exist while their part is off (`ERB_GCDBarFrame` and the ABR anchors). A frame that exists is not proof its part is on.
- Two frames have no name: Target Distance and Self Combat Text. They are found by their unlock keys.
- FE and MT gate by client in their .toc (`AllowLoadGameType`).
