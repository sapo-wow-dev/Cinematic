-- Cinematic: FlareUI, a whole-UI suite (one addon, a module per part). It
-- swaps the game's unit frames, buffs, quest tracker, party and raid frames
-- and XP bar for its own, which fade with the frames they stand in for and
-- follow the same rows on the Standard Frames page. It keeps the game's
-- action bars, minimap and damage meter, skinned. Its boss frames, with no
-- game frame to follow, get a row on the Advanced Frames page.
--
-- It sets alphas itself: its unit frames' fade-out (out of combat with no
-- target) and its quest items' are its own frames, so they're hooked; its
-- Show choices (Mouseover, Combat...) set the game's action bars, bag bar and
-- micro menu, and its damage meter fade the game's meter: followed. The
-- game's TargetFrame it keeps up, invisible, in the Gamepad UI is left alone.
-- Its minimap and tooltip looks each get an Addon Conflicts row against our
-- Style pages. Its minimap edge icons (durability, group finder eye, vehicle
-- exit) copy the minimap's alpha themselves, so they fade with the Minimap
-- row with nothing from us. Its windows, popups and hidden helpers are listed
-- in Tools/offline/addon-frames/FlareUI.txt.
local _, ns = ...
local L = ns.L

-- Advanced Frames rows: its frames with no game frame to follow.
table.insert(ns.ADDON_FRAMES, {
	key = "flareBoss", addon = "FlareUI",
	label = "FlareUI Boss Frames", short = "FlareUI bosses",
	about = L["its boss frames"],
	names = { "FlareUI_Boss" },
	hookAlpha = true,
})
-- Its row of icons for your class's missing buffs, out of fights (off in its
-- options to start with). It fades the row in and out itself: hooked.
table.insert(ns.ADDON_FRAMES, {
	key = "flareReminders", addon = "FlareUI",
	label = "FlareUI Buff Reminders", short = "FlareUI reminders",
	about = L["its icons for your missing buffs"],
	names = { "FlareUI_BuffReminders" },
	hookAlpha = true,
})
-- What you loot, floating up beside your character (off in its options to
-- start with).
table.insert(ns.ADDON_FRAMES, {
	key = "flareLootFeed", addon = "FlareUI",
	label = "FlareUI Loot Feed", short = "FlareUI loot feed",
	about = L["what you loot, beside your character"],
	names = { "FlareUI_LootFeed" },
})

-- Its frames standing in for the game's, by Standard Frames row: the row,
-- the fade group, and the frames. (Its health bar under your character is
-- the personal health bar; its power, druid mana and combo points the
-- personal resource bar.)
local ROWS = {
	{ "player", "player", "FlareUI_UF_Player", "FlareUI_Totems" },
	{ "petframe", "player", "FlareUI_UF_Pet" },
	{ "target", "target", "FlareUI_UF_Target" },
	{ "tot", "target", "FlareUI_UF_TargetOfTarget" },
	{ "focus", "target", "FlareUI_UF_Focus", "FlareUI_UF_TargetOfFocus" },
	{ "castbar", "castbar", "FlareUI_UF_PlayerCastBar" },
	{ "prd", "prd", "FlareUI_Resource_health" },
	{ "prdpower", "prdpower", "FlareUI_Resource_power", "FlareUI_Resource_mana", "FlareUI_Resource_combo" },
	{ "swing", "swing", "FlareUI_Resource_swingMain", "FlareUI_Resource_swingOff", "FlareUI_Resource_swingRanged" },
	{ "buffs", "buffs", "FlareUI_Buffs", "FlareUI_Debuffs" },
	{ "quests", "quests", "FlareUI_ObjectiveTracker" },
	{ "party", "party", "FlareUI_Party" },
	{ "xp", "bars", "FlareUI_XPBar" },
	-- (The panel its minimap's buttons are gathered into.)
	{ "minimap", "minimap", "FlareUI_MinimapBag" },
	-- In battlegrounds: its flag carrier tiles, in place of the game's.
	{ "flags", "flags", "FlareUI_FlagCarriers" },
	-- The box it draws behind the game's event boxes at the top of the screen.
	{ "topcenter", "topcenter", "FlareUI_BattlegroundObjectivesBox" },
}

-- The game's frames its Show choices and damage meter fade.
local FOLLOWED = {
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
	"MultiBar5", "MultiBar6", "MultiBar7", "PetActionBar", "StanceBar", "BagsBar", "MicroMenuContainer",
	"DamageMeter",
}

-- In the Gamepad UI it can't park the game's TargetFrame (the gamepad's
-- target menu opens on it and closes if it's hidden), so it keeps it shown,
-- at alpha 0, events off and mouse off, over its own target frame. We used to
-- fade it with the Target row like any game frame: each time the row came
-- back, it was put back to full, a frozen copy of the game's target frame
-- drawn over FlareUI's ("super glitchy", a player's report 2026-11-23). So
-- once it's kept that way, it's left alone and back at 0. (Without the
-- Gamepad UI it's hidden for good: nothing to do.)
local keptTarget = false
local function LeaveKeptTargetAlone()
	local frame = _G.TargetFrame
	if keptTarget or not frame or not rawget(frame, "FlareUI_Hidden") or not ns.Flag(frame:IsShown()) then
		return
	end
	keptTarget = true
	-- (Letting go puts it back to the alpha it had when first faded: 1.)
	ns.LeaveAlone({ "TargetFrame" })
	ns.SetFrameAlpha(frame, 0)
end
ns.FlareKeptTarget = function() return keptTarget end -- (Dev/FlareUISupportTest.lua)

ns.WhenAddonLoads("FlareUI", function()
	ns.FadeWithRows(ROWS)
	-- Kept up by the Health & Resources page like the game's frames (Show
	-- below, Opacity while hidden...): before, its player frame stayed faded
	-- after a fall or a fight, as only its HUD row's ticks counted.
	ns.AddPortraitFrame("FlareUI_UF_Player")
	ns.AddPetFrame("FlareUI_UF_Pet")
	ns.AddPortraitFrame("FlareUI_Resource_health", true)
	ns.AddPortraitFrame("FlareUI_Resource_power", true)
	ns.AddPortraitFrame("FlareUI_Resource_mana", true)
	-- Its XP bar stops taking the mouse when faded below 5% (its own SetAlpha
	-- hook), so the mouse never lands on it: hovered by its rect instead.
	ns.HOVER_BY_RECT.FlareUI_XPBar = true
	-- (A bar set to a Show choice other than Always is stepped towards its
	-- alpha every frame, so it's faded again every frame, not just each tick.)
	ns.FollowOwnAlpha(FOLLOWED)
	ns.syncEveryFrame = true
	-- Its raid frames (the main tanks' apart) fade with the game's, as Players.
	ns.FadeFoundByName("raidplayers", { "FlareUI_Raid", "FlareUI_RaidTanks" })
	ns.AddScanner(function()
		-- (It keeps the TargetFrame at login or, after a /reload in a fight, once
		-- the fight ends: checked with each scan till then.)
		LeaveKeptTargetAlone()
		-- Its quest item buttons, numbered as they're made (on UIParent: they're
		-- secure, so not in the tracker).
		local i = 1
		while _G["FlareUI_TrackerItem" .. i] do
			local button = _G["FlareUI_TrackerItem" .. i]
			if not ns.IsFaded(button) then
				ns.AddFoundFrame(button, "quests", true, true)
			end
			i = i + 1
		end
		-- The bar behind its minimap's zone name and clock (unnamed, in the
		-- minimap cluster): the Minimap header row.
		local flare = _G.FlareUI
		local header = type(flare) == "table" and type(flare.Minimap) == "table" and flare.Minimap.Header
		if type(header) == "table" and header.GetAlpha and not ns.IsFaded(header) then
			ns.AddFoundFrame(header, "minimapheader", false, false)
		end
	end)
end)

-- Its own settings, or nil before it's set up (FlareUI's namespace is its
-- global, its AceDB profile in .db).
local function FlareModule(name)
	local flare = _G.FlareUI
	local profile = type(flare) == "table" and type(flare.db) == "table" and flare.db.profile
	local mod = type(profile) == "table" and profile[name]
	return type(mod) == "table" and mod or nil
end

ns.WhenAddonLoads("FlareUI", function()
	-- Its minimap (its Minimap module, off to start with) takes the game's map
	-- and draws its own frame, header and edge icons on it, round or square.
	-- Theirs: the Minimap Style page stands aside; Ours: it's dressed anyway.
	ns.AddConflict({ key = "style:minimap", addon = "FlareUI", label = "Minimap look", group = "style",
		noBoth = true, styleSwitch = "minimapStyle",
		about = "Its minimap: left as FlareUI draws it, or also styled by the Style hub's Minimap page",
		theirs = function()
			local mod = FlareModule("minimap")
			return mod and mod.enabled and true or false
		end,
		ours = function() return ns.StyleOn("minimapStyle") end,
		onPick = function() if ns.RefreshMinimapStyle then ns.RefreshMinimapStyle() end end })
	-- Its tooltips (its Tooltips module, off to start with) color the game's
	-- tooltip border and background.
	ns.AddConflict({ key = "style:tooltip", addon = "FlareUI", label = "Tooltip look", group = "style",
		noBoth = true, styleSwitch = "tooltipStyle",
		about = "How tooltips look: the Interface hub's Tooltip Style page, or FlareUI's tooltips",
		theirs = function()
			local mod = FlareModule("tooltips")
			return mod and mod.enabled and true or false
		end,
		ours = function() return ns.StyleOn("tooltipStyle") end })
end)

-- The addon kit (Tools/addon-kit): what differs from the no-addons baseline
-- with FlareUI loaded, and why it's meant.
-- The game frames its own stand in for: parked on its hidden parent, or
-- hidden. Its frames fade with their rows instead (ROWS above).
ns.AddonKitExpect("FlareUI", "frame.buffs", "BuffFrame.*", "its buff bar stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "frame.buffs", "DebuffFrame.*", "its debuff bar stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "touch.BuffFrame", "*", "its buff bar stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "touch.DebuffFrame", "*", "its debuff bar stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "frame.player", "PlayerFrame.*", "its player frame stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "touch.PlayerFrame", "*", "its player frame stands in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "frame.petframe", "PetFrame.parent", "its pet frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "touch.PetFrame", "parent", "its pet frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "frame.target", "TargetFrame.parent", "its target frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "touch.TargetFrame", "parent", "its target frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "frame.focus", "FocusFrame.parent", "its focus frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "touch.FocusFrame", "parent", "its focus frame stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "frame.castbar", "PlayerCastingBarFrame.parent", "its cast bar stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "touch.PlayerCastingBarFrame", "parent", "its cast bar stands in: the game's parked")
ns.AddonKitExpect("FlareUI", "frame.totems", "TotemFrame.parent", "the game's totems moved into FlareUI_Totems (Player row)")
ns.AddonKitExpect("FlareUI", "touch.TotemFrame", "parent", "the game's totems moved into FlareUI_Totems (Player row)")
ns.AddonKitExpect("FlareUI", "frame.quests", "ObjectiveTrackerFrame.*", "its quest tracker stands in: the game's hidden")
ns.AddonKitExpect("FlareUI", "touch.ObjectiveTrackerFrame", "*", "its quest tracker stands in: the game's hidden")
ns.AddonKitExpect("FlareUI", "frame.xp", "MainStatusTrackingBarContainer.*", "its XP bar stands in: the game's hidden")
ns.AddonKitExpect("FlareUI", "frame.gamepadxp", "MainStatusTrackingBarContainer.*", "its XP bar stands in: the game's hidden")
ns.AddonKitExpect("FlareUI", "touch.MainStatusTrackingBarContainer", "*", "its XP bar stands in: the game's hidden")
ns.AddonKitExpect("FlareUI", "touch.PartyFrame", "*", "its party frames stand in: the game's parked hidden")
ns.AddonKitExpect("FlareUI", "touch.CompactRaidFrameContainer", "parent", "its raid frames stand in: the game's parked")
ns.AddonKitExpect("FlareUI", "touch.Boss_TargetFrame", "parent", "its boss frames stand in: the game's parked")
-- Its chat: the game's tab dock hidden behind tabs of its own (which fade
-- with the chat), and the chat buttons moved onto its own bar (each still on
-- its row).
ns.AddonKitExpect("FlareUI", "frame.chattabs", "GeneralDockManager.alpha", "its own chat tabs: the game's dock at 0")
ns.AddonKitExpect("FlareUI", "touch.GeneralDockManager", "alpha", "its own chat tabs: the game's dock at 0")
ns.AddonKitExpect("FlareUI", "touch.ChatFrame_Tab", "alpha", "its own chat tabs: the game's at 0")
ns.AddonKitExpect("FlareUI", "frame.chatmenu", "ChatFrameMenuButton.parent", "moved onto its chat button bar")
ns.AddonKitExpect("FlareUI", "touch.ChatFrameMenuButton", "parent", "moved onto its chat button bar")
ns.AddonKitExpect("FlareUI", "frame.chatchannels", "ChatFrameChannelButton.parent", "moved onto its chat button bar")
ns.AddonKitExpect("FlareUI", "touch.ChatFrameChannelButton", "parent", "moved onto its chat button bar")
ns.AddonKitExpect("FlareUI", "frame.chatquickjoin", "QuickJoinToastButton.parent", "moved onto its chat button bar")
ns.AddonKitExpect("FlareUI", "touch.QuickJoinToastButton", "parent", "moved onto its chat button bar")
-- Its minimap: the compass ring off, and the game's addon drawer hidden
-- while its minimap bag lists the same entries (ours too).
ns.AddonKitExpect("FlareUI", "touch.MinimapCompassTexture", "*", "its minimap look: the compass ring off")
ns.AddonKitExpect("FlareUI", "touch.AddonCompartmentFrame", "*", "its minimap bag lists the drawer's entries instead")
-- Game functions it post-hooks (hooksecurefunc or AceHook's SecureHook): the
-- function is a new object, and ours still run.
ns.AddonKitExpect("FlareUI", "hook.ChatFrame1.AddMessage", "state", "its post-hook rewriting lines: ours still runs")
ns.AddonKitExpect("FlareUI", "hook.FCF_*", "state", "its post-hooks on the chat windows: ours still run")
ns.AddonKitExpect("FlareUI", "touch.FCF_*", "sameAsLogin", "its post-hooks on the chat windows: ours still run")
ns.AddonKitExpect("FlareUI", "hook.Minimap.SetMaskTexture", "state", "its post-hook keeping its map shape: ours still runs")
ns.AddonKitExpect("FlareUI", "hook.StaticPopup_Show", "state", "its post-hook: ours still runs")
ns.AddonKitExpect("FlareUI", "touch.StaticPopup_Show", "sameAsLogin", "its post-hook: ours still runs")
ns.AddonKitExpect("FlareUI", "hook.UpdateContainerFrameAnchors", "state", "its post-hook placing bags: ours still runs")
ns.AddonKitExpect("FlareUI", "touch.UpdateContainerFrameAnchors", "sameAsLogin", "its post-hook placing bags: ours still runs")
ns.AddonKitExpect("FlareUI", "hook.UpdateUIPanelPositions", "state", "its post-hook placing windows: ours still runs")
ns.AddonKitExpect("FlareUI", "touch.UpdateUIPanelPositions", "sameAsLogin", "its post-hook placing windows: ours still runs")
ns.AddonKitExpect("FlareUI", "touch.GameTooltip_SetDefaultAnchor", "sameAsLogin", "its post-hook placing tooltips: ours still runs")
ns.AddonKitExpect("FlareUI", "touch.PlayerFrame_To*Art", "sameAsLogin", "its post-hooks re-attaching its player extras")
