# FlareUI

Version read: 7.0.16 (_forever_ only), 2026-11-25 (code read, not yet proven by a run of the recipe)

## What it is
A whole-UI suite: one addon, a module per part, each with its own page and switch in its settings window. Every module starts off (Core.lua:463-1080, `enabled = false` in each).
- Unit frames (Unit Frames page): `FlareUI_UF_Player`, `_Pet`, `_Target`, `_TargetOfTarget`, `_Focus`, `_TargetOfFocus` (UnitFrames.lua:5944, secure buttons), its cast bar `FlareUI_UF_PlayerCastBar` (UnitFrames.lua:6239), totems `FlareUI_Totems` (Totems.lua:374), party `FlareUI_Party` (PartyFrames.lua:4138), raid `FlareUI_Raid` / `FlareUI_RaidTanks` (RaidFrames.lua:1289), bosses `FlareUI_Boss` (BossFrames.lua:614), battleground flag carriers `FlareUI_FlagCarriers` (FlagCarriers.lua:482).
- Resource bars (Resource Bars page): `FlareUI_Resource_<key>` (ResourceBars.lua:1068).
- Buffs & Debuffs page: `FlareUI_Buffs`, `FlareUI_Debuffs` (Auras.lua:1171); Buff Reminders page: `FlareUI_BuffReminders` (BuffReminders.lua:2723).
- Quest Tracker page: `FlareUI_ObjectiveTracker` (ObjectiveTracker.lua:3603).
- Action Bars page: the game's bars skinned, and its XP bar `FlareUI_XPBar` (XPBar.lua:761).
- Minimap page: the game's minimap redrawn, its button drawer `FlareUI_MinimapBag` (MinimapBag.lua:975).
- Bags & Looting page: Loot Feed `FlareUI_LootFeed` (LootFeed.lua:472).
- Always (no page switch): the plate behind the game's top-center event boxes `FlareUI_BattlegroundObjectivesBox` (Movers.lua:419).
- Also chat, tooltips, nameplates, meters, cooldowns, radial menu: not covered frames.

## How a player starts it
- First login with no module on: its setup tour (`FlareUI_Tour`, Welcome.lua:898) opens 2 s after login; in the Gamepad UI a small welcome (`FlareUI_Welcome`, Welcome.lua:104) instead (Welcome.lua:1012-1033). Closing either sets `FlareUI2_DB.global.welcomeSeen` (Welcome.lua:111, 906); a login with any module on sets it too (Welcome.lua:1025).
- After an update its What's new opens in the settings window 4 s after login, not in the Gamepad UI (Panel.lua:3530-3553).
- `/fui` or `/flareui` opens or closes its settings window `FlareUI_SettingsPanel` (Launcher.lua:186-192, Panel.lua:2919); `/fui tour` the tour; `/fui buff` the Buff Reminders page; `/rl` reloads (Launcher.lua:169).
- Also: the minimap's addon button (left-click: settings, Launcher.lua:279), Options > AddOns > FlareUI > Open Configuration (not in the Gamepad UI, Launcher.lua:120-138), a key binding.
- Each page has a switch by its title, or a Turn On button while off (Panel.lua:3222, 3333). Modules start at login only (Core.lua:3749-3780), so a switch asks for a reload: Reload Now at the bottom of the window (Panel.lua:3418), then Reload Now in its box (Core.lua:3611).
- Settings are per profile (AceDB `FlareUI2_DB`, "Default" shared), the profile picked per character (Core.lua:3732).

## What each part needs before it shows
- Every unit frame: Unit Frames on, `unitframes.enabled` (off by default, Core.lua:635); each frame's own switch on (player, target, focus, pet, tot, tof on by default, Core.lua:769-793; party, raid, boss on, Core.lua:689-747; cast bar on, Core.lua:767).
- Flag carriers: Unit Frames on and `unitframes.flagCarriers.enabled` (off by default, Core.lua:758; FlagCarriers.lua:441), tiles only in a battleground.
- Boss frames: a boss fight (or Edit Mode).
- Party / raid: a group of that kind.
- Resource bars: `unitframes.resource.enabled` (off, Core.lua:668) and at least one bar on (ResourceBars.lua:2514).
- Buffs / debuffs: `auras.enabled` (off, Core.lua:844); never in the Gamepad UI (Auras.lua:1224).
- Buff reminders: `auras.reminders` (off, Core.lua:855); never in the Gamepad UI (BuffReminders.lua:2698); only while a class buff is missing, out of fights.
- Quest tracker: `objectivetracker.enabled` (off, Core.lua:961); in the Gamepad UI only with `padBlizzard` off (ObjectiveTracker.lua:168).
- XP bar: `actionbars.enabled` (off, Core.lua:521) and its XP Bar switch not off (XPBar.lua:818).
- Minimap bag: `minimap.enabled` (off, Core.lua:604), drawer style not Off (MinimapBag.lua:77).
- Loot feed: the bag module on (`tweaks.bagModule`, Core.lua:1376) and `tweaks.lootFeed` (off, Core.lua:1089; LootFeed.lua:465); something looted.
- Battleground objectives box: made at login unless `global.moveLootToasts` is false or in the Gamepad UI (Movers.lua:436, 472-482); shown only while the game's top-center widgets show something (battleground scores, some zone events, Movers.lua:410-416).

## Set up for a test
- by code: `FlareUI` is its whole namespace as a global (Core.lua:9): `FlareUI.db.profile.<module>`, `FlareUI.db.global`, `FlareUI.SettingsPanel`, `FlareUI.IsGamepadUI()` are all reachable.
- by code: its tour or welcome up -> `FlareUI_Tour:Hide()` / `FlareUI_Welcome:Hide()` (sets `welcomeSeen`: kept and put back). The recipe does this.
- by code: Unit Frames off -> `FlareUI.SettingsPanel:Open("uf")` opens its window on that page (Panel.lua:3504). The recipe does this, not in the Gamepad UI (code opening its window there is what Launcher.lua:118 warns hangs the client) and not in a fight.
- by hand: in FlareUI's window (Unit Frames page) click Turn On, then Reload Now at the bottom, then Reload Now in the box. Setting `FlareUI.db.profile.unitframes.enabled = true` does the same, but only takes after a reload, so the recipe leaves it to these clicks (the run picks up at the next step after the reload). Once on, it stays on: it's the player's own setup, not put back.
- by hand: the other modules the same way on their pages (Buffs & Debuffs, Buff Reminders, Quest Tracker, Action Bars, Minimap, Resource Bars; Loot Feed on Bags & Looting): not part of the recipe's `ready` (it needs only the unit frames, what /cine debug flareui checks). Rows of a module that's off simply have no frame.
- out of reach: modules start only at PLAYER_LOGIN (Core.lua:3749); calling `FlareUI.modules.X:Init()` from a test would skip its login order and make secure frames mid-session: don't. Battleground-only states (flag carriers, the objectives box showing): the support test's "own" step skips them when not made (Dev/FlareUISupportTest.lua).

## Surprises
- Every module is off on a fresh install: no FlareUI frame at all until the tour or the pages turn some on, and a reload.
- In the Gamepad UI it keeps the game's TargetFrame shown at alpha 0 over its own (Support/FlareUI.lua: left alone by us); its buffs, buff reminders and loot/toast movers don't load there at all.
- Its unit frames, XP bar and the game's bars fade themselves (Visibility.lua, Show choices); the XP bar drops the mouse below 5% (Support/FlareUI.lua).
- `/rl` is its reload; its reload dialogs (`FlareUIDialogReload`) are secure reload buttons.
- What's new can open over the screen 4 s after a login following an update (not in the Gamepad UI).
